#import <AVFAudio/AVFAudio.h>
#import <UIKit/UIKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include "ipados_platform.h"
#include "../../common/ipados_audio_engine.h"
#include "common/install_transaction.h"
#include "common/iso9660.h"
#include "common/ipados_localization.h"
#include "common/ipados_touch.h"
#include "common/savegame_transfer.h"
#include "third_party/SDL2/include/SDL.h"
#include "third_party/unshieldv3/ISArchiveV3.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <fstream>
#include <functional>
#include <fcntl.h>
#include <stdexcept>
#include <string>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

extern "C" bool TiberianDawn_ValidateSaveGame(const char* path,
                                             char* description,
                                             size_t description_capacity,
                                             unsigned* scenario,
                                             int* faction);

namespace
{
NSString* const ProductDirectory = @"TiberianDawn";
NSString* const GameDirectory = @"vanillatd";
NSString* const LanguagePreferenceKey = @"TiberianDawn.LanguagePreference";
NSString* const TouchGuideShownKey = @"TiberianDawn.TouchGuideShown.v1";

int StoredLanguagePreference()
{
    const NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:LanguagePreferenceKey];
    return value >= IPAD_LANGUAGE_SYSTEM && value <= IPAD_LANGUAGE_ENGLISH
        ? static_cast<int>(value)
        : IPAD_LANGUAGE_SYSTEM;
}

IPadLanguage EffectiveLanguage()
{
    NSString* tag = NSLocale.preferredLanguages.firstObject ?: @"en";
    return Resolve_IPad_Language(StoredLanguagePreference(), tag.UTF8String);
}

NSString* L(const char* key)
{
    return [NSString stringWithUTF8String:IPad_Localized_Text(EffectiveLanguage(), key)];
}

std::string Upper(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::toupper(c));
    });
    return value;
}

NSURL* LibraryDataURL()
{
    NSURL* applicationSupport = [[[NSFileManager defaultManager]
        URLsForDirectory:NSApplicationSupportDirectory
               inDomains:NSUserDomainMask] firstObject];
    return [[applicationSupport URLByAppendingPathComponent:ProductDirectory isDirectory:YES]
        URLByAppendingPathComponent:GameDirectory isDirectory:YES];
}

NSURL* LegacyDataURL()
{
    NSURL* documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                               inDomains:NSUserDomainMask] firstObject];
    return [[[documents URLByAppendingPathComponent:ProductDirectory isDirectory:YES]
        URLByAppendingPathComponent:GameDirectory isDirectory:YES] URLByStandardizingPath];
}

NSArray<NSURL*>* LocalGoldCDURLs()
{
    NSURL* documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                               inDomains:NSUserDomainMask] firstObject];
    if (!documents) return @[];

    NSFileManager* manager = [NSFileManager defaultManager];
    NSMutableArray<NSURL*>* result = [NSMutableArray arrayWithCapacity:2];
    for (NSString* name in @[ @"CNC95_GDI.iso", @"CNC95_Nod.iso" ]) {
        NSURL* url = [documents URLByAppendingPathComponent:name isDirectory:NO];
        NSDictionary* attributes = [manager attributesOfItemAtPath:url.path error:nil];
        if (![attributes[NSFileType] isEqualToString:NSFileTypeRegular]
            || [attributes[NSFileSize] unsignedLongLongValue] == 0) {
            return @[];
        }
        [result addObject:url];
    }
    return result;
}

bool ValidData(NSURL* directory)
{
    NSArray<NSString*>* required = @[
        @"CCLOCAL.MIX", @"CONQUER.MIX", @"DESEICNH.MIX", @"LOCAL.MIX", @"SOUNDS.MIX", @"SPEECH.MIX",
        @"TEMPICNH.MIX", @"TRANSIT.MIX", @"UPDATE.MIX", @"UPDATEC.MIX", @"WINTICNH.MIX",
        @"TEMPERAT.MIX", @"DESERT.MIX", @"WINTER.MIX",
        @"gdi/GENERAL.MIX", @"gdi/MOVIES.MIX", @"gdi/SCORES.MIX",
        @"nod/GENERAL.MIX", @"nod/MOVIES.MIX", @"nod/SCORES.MIX"
    ];
    for (NSString* file in required) {
        NSURL* url = [directory URLByAppendingPathComponent:file];
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
        if (!attributes || ![attributes[NSFileType] isEqualToString:NSFileTypeRegular]
            || [attributes[NSFileSize] unsignedLongLongValue] == 0) {
            return false;
        }
    }
    return true;
}

void ExcludeFromBackup(NSURL* directory)
{
    [directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
}

void AtomicInstall(NSURL* staging, NSURL* destination)
{
    NSFileManager* manager = [NSFileManager defaultManager];
    NSError* directoryError = nil;
    if (![manager createDirectoryAtURL:[destination URLByDeletingLastPathComponent]
            withIntermediateDirectories:YES attributes:nil error:&directoryError]) {
        throw std::runtime_error([[directoryError localizedDescription] UTF8String]);
    }
    NSURL* old = [[destination URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"vanillatd.old" isDirectory:YES];
    InstallOperations operations;
    operations.exists = [manager](const std::string& path) {
        return [manager fileExistsAtPath:@(path.c_str())];
    };
    operations.remove = [manager](const std::string& path) {
        NSString* value = @(path.c_str());
        return ![manager fileExistsAtPath:value] || [manager removeItemAtPath:value error:nil];
    };
    operations.move = [manager](const std::string& source, const std::string& target) {
        return [manager moveItemAtPath:@(source.c_str()) toPath:@(target.c_str()) error:nil];
    };
    const InstallCommitResult result = Commit_Staged_Install(staging.fileSystemRepresentation,
                                                              destination.fileSystemRepresentation,
                                                              old.fileSystemRepresentation,
                                                              operations);
    if (!result.committed) {
        if (result.error == INSTALL_COMMIT_ROLLBACK_FAILED) {
            throw std::runtime_error(L("error_atomic_rollback").UTF8String);
        }
        throw std::runtime_error(L("error_atomic_install").UTF8String);
    }
    ExcludeFromBackup(destination);
}

void EnsureImportCapacity(NSURL* directory)
{
    NSError* error = nil;
    NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfFileSystemForPath:directory.path error:&error];
    const unsigned long long available = [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
    const unsigned long long required = 1200ULL * 1024ULL * 1024ULL;
    const ImportCapacityDecision decision = Evaluate_Import_Capacity(attributes != nil && error == nil,
                                                                      available,
                                                                      required);
    if (decision == IMPORT_CAPACITY_UNKNOWN) {
        throw std::runtime_error(L("error_storage_unknown").UTF8String);
    }
    if (decision == IMPORT_CAPACITY_INSUFFICIENT) {
        throw std::runtime_error(L("error_storage_low").UTF8String);
    }
}

void CopyPreparedDirectory(NSURL* source, NSURL* staging)
{
    NSFileManager* manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:nil];
    NSError* listingError = nil;
    NSArray<NSURL*>* rootItems = [manager contentsOfDirectoryAtURL:source
                                        includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                             error:&listingError];
    if (!rootItems) {
        throw std::runtime_error([[listingError localizedDescription] UTF8String]);
    }
    for (NSURL* item in rootItems) {
        NSNumber* isDirectory = nil;
        [item getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        NSString* name = item.lastPathComponent;
        if (isDirectory.boolValue
            && ([name caseInsensitiveCompare:@"gdi"] == NSOrderedSame
                || [name caseInsensitiveCompare:@"nod"] == NSOrderedSame)) {
            NSString* normalizedSide = [name lowercaseString];
            NSURL* sideDestination = [staging URLByAppendingPathComponent:normalizedSide isDirectory:YES];
            [manager createDirectoryAtURL:sideDestination withIntermediateDirectories:YES attributes:nil error:nil];
            for (NSURL* sideItem in [manager contentsOfDirectoryAtURL:item
                                           includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                error:nil]) {
                if ([sideItem.pathExtension caseInsensitiveCompare:@"MIX"] != NSOrderedSame) continue;
                NSError* error = nil;
                if (![manager copyItemAtURL:sideItem
                                      toURL:[sideDestination URLByAppendingPathComponent:[sideItem.lastPathComponent uppercaseString]]
                                      error:&error]) {
                    throw std::runtime_error([[error localizedDescription] UTF8String]);
                }
            }
        } else if (!isDirectory.boolValue && [item.pathExtension caseInsensitiveCompare:@"MIX"] == NSOrderedSame) {
            NSError* error = nil;
            if (![manager copyItemAtURL:item
                                  toURL:[staging URLByAppendingPathComponent:[name uppercaseString]]
                                  error:&error]) {
                throw std::runtime_error([[error localizedDescription] UTF8String]);
            }
        }
    }
}

void WriteBytes(const std::vector<uint8_t>& bytes, const std::string& path)
{
    std::ofstream output(path.c_str(), std::ios::binary | std::ios::trunc);
    if (!bytes.empty()) {
        output.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
    }
    if (!output) {
        throw std::runtime_error(L("error_write_install").UTF8String);
    }
}

void ExtractSetupFiles(const std::string& setupPath, NSURL* staging)
{
    ISArchiveV3 archive(setupPath);
    const char* names[] = {"CCLOCAL.MIX", "DESEICNH.MIX", "LOCAL.MIX", "SPEECH.MIX", "TEMPICNH.MIX",
                           "TRANSIT.MIX", "UPDATE.MIX", "UPDATEC.MIX", "WINTICNH.MIX"};
    for (const char* name : names) {
        const std::string archived = std::string("C&C95\\") + name;
        if (archive.exists(archived)) {
            WriteBytes(archive.decompress(archived), [[[staging URLByAppendingPathComponent:@(name)] path] UTF8String]);
        }
    }
}

void ExtractISOs(NSArray<NSURL*>* urls, NSURL* staging)
{
    NSFileManager* manager = [NSFileManager defaultManager];
    [manager createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:nil];
    [manager createDirectoryAtURL:[staging URLByAppendingPathComponent:@"gdi"] withIntermediateDirectories:YES attributes:nil error:nil];
    [manager createDirectoryAtURL:[staging URLByAppendingPathComponent:@"nod"] withIntermediateDirectories:YES attributes:nil error:nil];

    bool haveGDI = false;
    bool haveNod = false;
    bool setupDone = false;
    const char* common[] = {"CONQUER.MIX", "SOUNDS.MIX", "DESERT.MIX", "TEMPERAT.MIX", "WINTER.MIX"};
    const char* faction[] = {"GENERAL.MIX", "MOVIES.MIX", "SCORES.MIX"};
    for (NSURL* url in urls) {
        const bool accessed = [url startAccessingSecurityScopedResource];
        try {
            ISO9660 iso(url.fileSystemRepresentation);
            const std::string volume = Upper(iso.Volume());
            NSString* side = volume.find("GDI") != std::string::npos ? @"gdi" :
                             (volume.find("NOD") != std::string::npos ? @"nod" : nil);
            if (side == nil) {
                throw std::runtime_error(L("error_disc_identity").UTF8String);
            }
            haveGDI = haveGDI || [side isEqualToString:@"gdi"];
            haveNod = haveNod || [side isEqualToString:@"nod"];
            for (const char* name : common) {
                NSURL* destination = [staging URLByAppendingPathComponent:@(name)];
                if (iso.Has(name) && ![manager fileExistsAtPath:destination.path]) {
                    iso.Extract(name, destination.fileSystemRepresentation);
                }
            }
            for (const char* name : faction) {
                iso.Extract(name, [[[staging URLByAppendingPathComponent:side] URLByAppendingPathComponent:@(name)] path].UTF8String);
            }
            if (!setupDone && iso.Has("INSTALL/SETUP.Z")) {
                NSURL* setup = [staging URLByAppendingPathComponent:@".SETUP.Z.importing"];
                @try {
                    iso.Extract("INSTALL/SETUP.Z", setup.fileSystemRepresentation);
                    ExtractSetupFiles(setup.fileSystemRepresentation, staging);
                } @catch (NSException* exception) {
                    [manager removeItemAtURL:setup error:nil];
                    throw std::runtime_error([[exception reason] UTF8String]);
                }
                [manager removeItemAtURL:setup error:nil];
                setupDone = true;
            }
        } catch (...) {
            if (accessed) [url stopAccessingSecurityScopedResource];
            throw;
        }
        if (accessed) [url stopAccessingSecurityScopedResource];
    }
    if (!haveGDI || !haveNod) {
        throw std::runtime_error(L("error_both_discs").UTF8String);
    }
}

} // namespace

@interface TiberianDawnImportGuideController : UIViewController <UIDocumentPickerDelegate>
@property(nonatomic, strong) NSArray<NSURL*>* URLs;
@property(nonatomic) BOOL finished;
@end

@implementation TiberianDawnImportGuideController

- (UILabel*)guideLabel:(NSString*)text font:(UIFont*)font color:(UIColor*)color
{
    UILabel* label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    UIColor* background = [UIColor colorWithRed:0.035 green:0.055 blue:0.055 alpha:1.0];
    UIColor* card = [UIColor colorWithRed:0.075 green:0.105 blue:0.095 alpha:1.0];
    UIColor* primary = [UIColor colorWithRed:0.88 green:0.62 blue:0.10 alpha:1.0];
    UIColor* secondary = [UIColor colorWithWhite:0.80 alpha:1.0];
    self.view.backgroundColor = background;

    UIScrollView* scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.alwaysBounceVertical = YES;
    scroll.accessibilityLabel = L("import_guide_accessibility");
    [self.view addSubview:scroll];

    UIStackView* content = [UIStackView new];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.axis = UILayoutConstraintAxisVertical;
    content.spacing = 14;
    [scroll addSubview:content];

    UIImageView* symbol = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"externaldrive.badge.plus"]];
    symbol.translatesAutoresizingMaskIntoConstraints = NO;
    symbol.tintColor = primary;
    symbol.contentMode = UIViewContentModeScaleAspectFit;
    [symbol.heightAnchor constraintEqualToConstant:58].active = YES;
    symbol.isAccessibilityElement = NO;
    [content addArrangedSubview:symbol];

    UILabel* title = [self guideLabel:L("import_title")
                                 font:[UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle]
                                color:UIColor.whiteColor];
    title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    title.accessibilityTraits = UIAccessibilityTraitHeader;
    [content addArrangedSubview:title];

    UILabel* introduction = [self guideLabel:
        L("import_intro")
                                              font:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                             color:secondary];
    introduction.textAlignment = NSTextAlignmentCenter;
    [content addArrangedSubview:introduction];

    UIView* requirementsCard = [UIView new];
    requirementsCard.backgroundColor = card;
    requirementsCard.layer.cornerRadius = 16;
    requirementsCard.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(18, 18, 18, 18);
    UIStackView* requirements = [UIStackView new];
    requirements.translatesAutoresizingMaskIntoConstraints = NO;
    requirements.axis = UILayoutConstraintAxisVertical;
    requirements.spacing = 9;
    [requirementsCard addSubview:requirements];
    [NSLayoutConstraint activateConstraints:@[
        [requirements.leadingAnchor constraintEqualToAnchor:requirementsCard.layoutMarginsGuide.leadingAnchor],
        [requirements.trailingAnchor constraintEqualToAnchor:requirementsCard.layoutMarginsGuide.trailingAnchor],
        [requirements.topAnchor constraintEqualToAnchor:requirementsCard.layoutMarginsGuide.topAnchor],
        [requirements.bottomAnchor constraintEqualToAnchor:requirementsCard.layoutMarginsGuide.bottomAnchor]
    ]];
    UILabel* needTitle = [self guideLabel:L("import_need_title")
                                     font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
                                    color:UIColor.whiteColor];
    needTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [requirements addArrangedSubview:needTitle];
    [requirements addArrangedSubview:[self guideLabel:
        L("import_requirements")
                                                  font:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                                 color:secondary]];
    [content addArrangedSubview:requirementsCard];

    UILabel* stepsTitle = [self guideLabel:L("import_steps_title")
                                      font:[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]
                                     color:UIColor.whiteColor];
    stepsTitle.accessibilityTraits = UIAccessibilityTraitHeader;
    [content addArrangedSubview:stepsTitle];
    [content addArrangedSubview:[self guideLabel:
        L("import_steps")
                                                font:[UIFont preferredFontForTextStyle:UIFontTextStyleBody]
                                               color:secondary]];

    UILabel* alternative = [self guideLabel:
        L("import_alternative")
                                             font:[UIFont preferredFontForTextStyle:UIFontTextStyleFootnote]
                                            color:[UIColor colorWithWhite:0.66 alpha:1.0]];
    [content addArrangedSubview:alternative];

    UIStackView* actions = [UIStackView new];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisVertical;
    actions.spacing = 8;
    actions.backgroundColor = background;
    actions.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(12, 24, 18, 24);
    actions.layoutMarginsRelativeArrangement = YES;
    [self.view addSubview:actions];

    UIButton* selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    selectButton.translatesAutoresizingMaskIntoConstraints = NO;
    [selectButton setTitle:L("select_game_data") forState:UIControlStateNormal];
    [selectButton setTitleColor:[UIColor colorWithRed:0.04 green:0.05 blue:0.04 alpha:1.0] forState:UIControlStateNormal];
    selectButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    selectButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    selectButton.backgroundColor = primary;
    selectButton.layer.cornerRadius = 12;
    selectButton.accessibilityHint = L("select_game_data_hint");
    [selectButton.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
    [selectButton addTarget:self action:@selector(selectSources:) forControlEvents:UIControlEventTouchUpInside];
    [actions addArrangedSubview:selectButton];

    if (LocalGoldCDURLs().count == 2) {
        UIButton* localButton = [UIButton buttonWithType:UIButtonTypeSystem];
        localButton.translatesAutoresizingMaskIntoConstraints = NO;
        [localButton setTitle:L("use_transferred_cds") forState:UIControlStateNormal];
        [localButton setTitleColor:primary forState:UIControlStateNormal];
        localButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        localButton.titleLabel.adjustsFontForContentSizeCategory = YES;
        localButton.layer.borderColor = primary.CGColor;
        localButton.layer.borderWidth = 1.5;
        localButton.layer.cornerRadius = 12;
        localButton.accessibilityHint = L("use_transferred_cds_hint");
        [localButton.heightAnchor constraintGreaterThanOrEqualToConstant:52].active = YES;
        [localButton addTarget:self action:@selector(useTransferredSources:) forControlEvents:UIControlEventTouchUpInside];
        [actions insertArrangedSubview:localButton atIndex:0];
    }

    UIButton* laterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [laterButton setTitle:L("setup_later") forState:UIControlStateNormal];
    [laterButton setTitleColor:secondary forState:UIControlStateNormal];
    laterButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    [laterButton.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
    laterButton.accessibilityHint = L("setup_later_hint");
    [laterButton addTarget:self action:@selector(importLater:) forControlEvents:UIControlEventTouchUpInside];
    [actions addArrangedSubview:laterButton];

    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:actions.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
        [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
        [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
        [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
        [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48],
        [actions.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [actions.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [actions.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
}

- (void)useTransferredSources:(id)sender
{
    self.URLs = LocalGoldCDURLs();
    self.finished = self.URLs.count == 2;
}

- (void)selectSources:(id)sender
{
    // iPadOS currently maps the .iso extension to a dynamic UTI rather than
    // public.disk-image. Include that exact extension-derived type so ISO-9660
    // images remain selectable without widening the picker to arbitrary data.
    UTType* isoType = [UTType typeWithFilenameExtension:@"iso" conformingToType:UTTypeData];
    NSArray<UTType*>* contentTypes = nil;
#if defined(VISIONOS_PORT)
    // The visionOS Files provider does not currently expose every .iso file
    // through either the extension-derived type or public.disk-image.  Admit
    // generic data there so iCloud ISO placeholders remain visible; the
    // importer still validates ISO-9660 structure and both C&C Gold discs
    // before committing anything to the app container.
    contentTypes = isoType
        ? @[ isoType, UTTypeDiskImage, UTTypeData, UTTypeFolder ]
        : @[ UTTypeDiskImage, UTTypeData, UTTypeFolder ];
#else
    contentTypes = isoType
        ? @[ isoType, UTTypeDiskImage, UTTypeFolder ]
        : @[ UTTypeDiskImage, UTTypeFolder ];
#endif
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:contentTypes asCopy:NO];
    picker.allowsMultipleSelection = YES;
    picker.delegate = self;
    picker.title = L("picker_both_discs");
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)importLater:(id)sender
{
    self.URLs = @[];
    self.finished = YES;
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    self.URLs = urls;
    self.finished = YES;
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
    // Return to the guide so the instructions remain available. "Später"
    // is an explicit decision on the guide itself.
}
@end

static bool SyncSavePath(const std::string& path, bool directory)
{
    int flags = O_RDONLY;
#ifdef O_DIRECTORY
    if (directory) flags |= O_DIRECTORY;
#else
    (void)directory;
#endif
    const int descriptor = open(path.c_str(), flags);
    if (descriptor < 0) return false;
    const bool result = fsync(descriptor) == 0;
    close(descriptor);
    return result;
}

static NSArray<NSDictionary*>* LoadManualSaveRecords(void)
{
    NSFileManager* manager = [NSFileManager defaultManager];
    NSURL* directory = LegacyDataURL();
    [manager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSArray<NSURL*>* files = [manager contentsOfDirectoryAtURL:directory
                                    includingPropertiesForKeys:@[NSURLIsRegularFileKey, NSURLContentModificationDateKey]
                                                       options:NSDirectoryEnumerationSkipsHiddenFiles
                                                         error:nil];
    NSMutableArray<NSDictionary*>* records = [NSMutableArray array];
    for (NSURL* url in files) {
        const std::string name(url.lastPathComponent.UTF8String ?: "");
        if (!Is_Manual_Savegame_Name(name)) continue;

        char description[128] = {0};
        unsigned scenario = 0;
        int faction = 0;
        const bool valid = TiberianDawn_ValidateSaveGame(url.fileSystemRepresentation,
                                                       description,
                                                       sizeof(description),
                                                       &scenario,
                                                       &faction);
        NSString* title = valid && description[0] ? @(description) : L("save_invalid");
        NSString* side = faction == 1 ? @"Nod" : @"GDI";
        NSString* detail = valid
            ? [NSString stringWithFormat:@"%@ · Mission %u · %@", side, scenario, url.lastPathComponent]
            : [NSString stringWithFormat:L("save_excluded_format"), url.lastPathComponent];
        [records addObject:@{
            @"url": url,
            @"name": url.lastPathComponent,
            @"title": title,
            @"detail": detail,
            @"valid": @(valid),
            @"scenario": @(scenario),
            @"faction": side,
            @"slot": @(Manual_Savegame_Slot(name))
        }];
    }
    [records sortUsingComparator:^NSComparisonResult(NSDictionary* left, NSDictionary* right) {
        return [left[@"slot"] compare:right[@"slot"]];
    }];
    return records;
}

static NSDictionary* ImportManualSaves(NSArray<NSURL*>* sources)
{
    NSFileManager* manager = [NSFileManager defaultManager];
    NSURL* directory = LegacyDataURL();
    NSError* directory_error = nil;
    if (![manager createDirectoryAtURL:directory
            withIntermediateDirectories:YES attributes:nil error:&directory_error]) {
        return @{@"count": @0, @"errors": @[[directory_error localizedDescription]]};
    }

    NSUInteger imported = 0;
    NSMutableArray<NSString*>* errors = [NSMutableArray array];
    for (NSURL* source in sources) {
        const bool accessed = [source startAccessingSecurityScopedResource];
        @autoreleasepool {
            try {
                NSNumber* regular = nil;
                NSNumber* size = nil;
                NSError* resource_error = nil;
                if (![source getResourceValue:&regular forKey:NSURLIsRegularFileKey error:&resource_error]
                    || !regular.boolValue
                    || ![source getResourceValue:&size forKey:NSURLFileSizeKey error:&resource_error]
                    || size.unsignedLongLongValue == 0
                    || size.unsignedLongLongValue > 128ULL * 1024ULL * 1024ULL) {
                    throw std::runtime_error(L("error_save_file").UTF8String);
                }

                NSArray<NSString*>* existing = [manager contentsOfDirectoryAtPath:directory.path error:nil];
                std::vector<std::string> names;
                for (NSString* name in existing) names.push_back(name.UTF8String ?: "");
                const int slot = First_Free_Manual_Savegame_Slot(names);
                if (slot < 0) throw std::runtime_error(L("error_save_slots").UTF8String);

                NSURL* temporary = [directory URLByAppendingPathComponent:@".savegame.importing"];
                NSURL* destination = [directory URLByAppendingPathComponent:@(Manual_Savegame_Name(slot).c_str())];
                [manager removeItemAtURL:temporary error:nil];
                NSError* copy_error = nil;
                if (![manager copyItemAtURL:source toURL:temporary error:&copy_error]) {
                    throw std::runtime_error(copy_error.localizedDescription.UTF8String);
                }

                char description[128] = {0};
                unsigned scenario = 0;
                int faction = 0;
                if (!TiberianDawn_ValidateSaveGame(temporary.fileSystemRepresentation,
                                                description,
                                                sizeof(description),
                                                &scenario,
                                                &faction)) {
                    [manager removeItemAtURL:temporary error:nil];
                    throw std::runtime_error(L("error_save_incompatible").UTF8String);
                }
                if (!SyncSavePath(temporary.fileSystemRepresentation, false)) {
                    [manager removeItemAtURL:temporary error:nil];
                    throw std::runtime_error(L("error_save_sync").UTF8String);
                }
                if (rename(temporary.fileSystemRepresentation, destination.fileSystemRepresentation) != 0) {
                    [manager removeItemAtURL:temporary error:nil];
                    throw std::runtime_error(L("error_save_atomic").UTF8String);
                }
                SyncSavePath(directory.fileSystemRepresentation, true);
                ++imported;
            } catch (const std::exception& error) {
                [manager removeItemAtURL:[directory URLByAppendingPathComponent:@".savegame.importing"] error:nil];
                [errors addObject:[NSString stringWithFormat:@"%@: %s", source.lastPathComponent, error.what()]];
            }
        }
        if (accessed) [source stopAccessingSecurityScopedResource];
    }
    return @{@"count": @(imported), @"errors": errors};
}

static NSArray<NSURL*>* PrepareSaveExports(NSArray<NSDictionary*>* records, NSString** failure)
{
    NSFileManager* manager = [NSFileManager defaultManager];
    NSURL* directory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
        URLByAppendingPathComponent:@"TiberianDawn-Save-Export" isDirectory:YES];
    [manager removeItemAtURL:directory error:nil];
    NSError* error = nil;
    if (![manager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        if (failure) *failure = error.localizedDescription;
        return @[];
    }

    NSMutableArray<NSURL*>* exports = [NSMutableArray array];
    for (NSDictionary* record in records) {
        if (![record[@"valid"] boolValue]) continue;
        const std::string name = Savegame_Export_Name([record[@"title"] UTF8String] ?: "",
                                                       [record[@"faction"] UTF8String] ?: "",
                                                       [record[@"scenario"] unsignedIntValue],
                                                       [record[@"slot"] intValue]);
        NSURL* destination = [directory URLByAppendingPathComponent:@(name.c_str())];
        if (![manager copyItemAtURL:record[@"url"] toURL:destination error:&error]) {
            [manager removeItemAtURL:directory error:nil];
            if (failure) *failure = error.localizedDescription;
            return @[];
        }
        [exports addObject:destination];
    }
    if (exports.count == 0 && failure) *failure = L("save_no_export");
    return exports;
}

@interface TiberianDawnSaveManagerController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate>
@property(nonatomic, strong) NSArray<NSDictionary*>* saves;
@property(nonatomic, strong) UITableView* table;
@property(nonatomic, strong) UILabel* statusLabel;
@property(nonatomic, strong) UIButton* importButton;
@property(nonatomic, strong) UIButton* exportButton;
@property(nonatomic, strong) UIButton* closeButton;
@property(nonatomic, strong) NSArray<NSURL*>* exportTemporaryURLs;
@property(nonatomic) BOOL awaitingImport;
@property(nonatomic) BOOL busy;
@property(nonatomic) BOOL finished;
@end

@implementation TiberianDawnSaveManagerController

- (UIButton*)actionButton:(NSString*)title selector:(SEL)selector primary:(BOOL)primary
{
    UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    button.titleLabel.adjustsFontForContentSizeCategory = YES;
    button.layer.cornerRadius = 10;
    button.backgroundColor = primary ? [UIColor colorWithRed:0.88 green:0.62 blue:0.10 alpha:1.0]
                                     : [UIColor colorWithWhite:0.16 alpha:1.0];
    [button setTitleColor:primary ? [UIColor colorWithWhite:0.03 alpha:1.0] : UIColor.whiteColor
                 forState:UIControlStateNormal];
    [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
    [button addTarget:self action:selector forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.055 alpha:1.0];

    UILabel* title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = L("save_manager_title");
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle];
    title.adjustsFontForContentSizeCategory = YES;
    title.textColor = UIColor.whiteColor;

    UILabel* explanation = [UILabel new];
    explanation.translatesAutoresizingMaskIntoConstraints = NO;
    explanation.text = L("save_manager_explanation");
    explanation.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    explanation.adjustsFontForContentSizeCategory = YES;
    explanation.textColor = [UIColor colorWithWhite:0.76 alpha:1.0];
    explanation.numberOfLines = 0;

    self.statusLabel = [UILabel new];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.adjustsFontForContentSizeCategory = YES;
    self.statusLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    self.statusLabel.numberOfLines = 0;

    self.table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.table.translatesAutoresizingMaskIntoConstraints = NO;
    self.table.backgroundColor = UIColor.clearColor;
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.allowsMultipleSelection = NO;

    self.importButton = [self actionButton:L("import") selector:@selector(importSaves:) primary:YES];
    self.exportButton = [self actionButton:L("export") selector:@selector(chooseExport:) primary:NO];
    self.closeButton = [self actionButton:L("done") selector:@selector(closeManager:) primary:NO];
    UIStackView* actions = [[UIStackView alloc] initWithArrangedSubviews:@[self.importButton, self.exportButton, self.closeButton]];
    actions.translatesAutoresizingMaskIntoConstraints = NO;
    actions.axis = UILayoutConstraintAxisHorizontal;
    actions.distribution = UIStackViewDistributionFillEqually;
    actions.spacing = 10;

    [self.view addSubview:title];
    [self.view addSubview:explanation];
    [self.view addSubview:self.statusLabel];
    [self.view addSubview:self.table];
    [self.view addSubview:actions];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [title.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [title.topAnchor constraintEqualToAnchor:safe.topAnchor constant:20],
        [explanation.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [explanation.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [explanation.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:explanation.bottomAnchor constant:8],
        [self.table.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.table.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.table.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:4],
        [self.table.bottomAnchor constraintEqualToAnchor:actions.topAnchor constant:-8],
        [actions.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:20],
        [actions.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-20],
        [actions.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-16]
    ]];
    [self reloadSaves];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, title);
}

- (void)reloadSaves
{
    self.saves = LoadManualSaveRecords();
    [self.table reloadData];
    NSUInteger valid = 0;
    for (NSDictionary* record in self.saves) if ([record[@"valid"] boolValue]) ++valid;
    self.statusLabel.text = valid == 0
        ? L("save_none")
        : [NSString stringWithFormat:L("save_count_format"),
                                     (unsigned long)valid];
    self.exportButton.enabled = valid > 0;
    self.exportButton.alpha = self.exportButton.enabled ? 1.0 : 0.45;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section { return self.saves.count; }

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    static NSString* identifier = @"SaveCell";
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    NSDictionary* record = self.saves[indexPath.row];
    cell.textLabel.text = record[@"title"];
    cell.detailTextLabel.text = record[@"detail"];
    cell.textLabel.textColor = [record[@"valid"] boolValue] ? UIColor.labelColor : UIColor.systemRedColor;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.accessoryType = [record[@"valid"] boolValue] ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDetailButton;
    return cell;
}

- (void)setBusyState:(BOOL)busy text:(NSString*)text
{
    self.busy = busy;
    self.importButton.enabled = !busy;
    self.exportButton.enabled = !busy && self.saves.count > 0;
    self.closeButton.enabled = !busy;
    if (text) self.statusLabel.text = text;
}

- (void)showAlert:(NSString*)title message:(NSString*)message
{
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L("ok") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)importSaves:(id)sender
{
    self.awaitingImport = YES;
    UTType* saveType = [UTType typeWithIdentifier:@"org.tiberiandawn.cncsave"];
    NSArray<UTType*>* types = saveType ? @[saveType, UTTypeData] : @[UTTypeData];
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForOpeningContentTypes:types asCopy:NO];
    picker.allowsMultipleSelection = YES;
    picker.delegate = self;
    picker.title = L("save_picker_import");
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)chooseExport:(id)sender
{
    NSIndexPath* selected = self.table.indexPathForSelectedRow;
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:L("save_export_title")
        message:L("save_export_message")
        preferredStyle:UIAlertControllerStyleAlert];
    if (selected && [self.saves[selected.row][@"valid"] boolValue]) {
        [alert addAction:[UIAlertAction actionWithTitle:L("selected")
            style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
                [self exportRecords:@[self.saves[selected.row]]];
            }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:L("all_valid")
        style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) { [self exportRecords:self.saves]; }]];
    [alert addAction:[UIAlertAction actionWithTitle:L("cancel") style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)exportRecords:(NSArray<NSDictionary*>*)records
{
    NSString* failure = nil;
    NSArray<NSURL*>* urls = PrepareSaveExports(records, &failure);
    if (urls.count == 0) {
        [self showAlert:L("export_unavailable") message:failure ?: L("no_valid_saves")];
        return;
    }
    self.awaitingImport = NO;
    self.exportTemporaryURLs = urls;
    UIDocumentPickerViewController* picker = [[UIDocumentPickerViewController alloc]
        initForExportingURLs:urls asCopy:YES];
    picker.delegate = self;
    picker.title = L("save_picker_export");
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)cleanupExports
{
    if (self.exportTemporaryURLs.count > 0) {
        NSURL* directory = [self.exportTemporaryURLs.firstObject URLByDeletingLastPathComponent];
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
    }
    self.exportTemporaryURLs = nil;
}

- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls
{
    if (!self.awaitingImport) {
        [self cleanupExports];
        [self showAlert:L("export_complete") message:L("export_complete_message")];
        return;
    }
    self.awaitingImport = NO;
    [self setBusyState:YES text:L("save_import_busy")];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSDictionary* result = ImportManualSaves(urls);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusyState:NO text:nil];
            [self reloadSaves];
            const NSUInteger count = [result[@"count"] unsignedIntegerValue];
            NSArray<NSString*>* errors = result[@"errors"];
            NSString* message = [NSString stringWithFormat:L("save_import_count_format"), (unsigned long)count];
            if (errors.count > 0) {
                message = [message stringByAppendingFormat:L("save_not_imported_format"), [errors componentsJoinedByString:@"\n"]];
            }
            [self showAlert:count > 0 ? L("import_complete") : L("import_unavailable") message:message];
        });
    });
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController*)controller
{
    if (!self.awaitingImport) [self cleanupExports];
    self.awaitingImport = NO;
}

- (void)closeManager:(id)sender
{
    if (!self.busy) self.finished = YES;
}
@end

namespace
{

NSArray<NSURL*>* PickSources()
{
    __block NSArray<NSURL*>* result = nil;
    void (^present)(void) = ^{
        TiberianDawnImportGuideController* guide = [TiberianDawnImportGuideController new];

        UIWindowScene* scene = nil;
        for (UIScene* candidate in UIApplication.sharedApplication.connectedScenes) {
            if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState != UISceneActivationStateUnattached) {
                scene = (UIWindowScene*)candidate;
                break;
            }
        }
        UIWindow* host = [[UIWindow alloc] initWithWindowScene:scene];
        host.rootViewController = guide;
        host.windowLevel = UIWindowLevelAlert;
        [host makeKeyAndVisible];

        while (!guide.finished) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }
        result = guide.URLs;
        host.hidden = YES;
    };
    if (NSThread.isMainThread) {
        present();
    } else {
        dispatch_sync(dispatch_get_main_queue(), present);
    }
    return result ?: @[];
}

UIWindowScene* ActiveWindowScene()
{
    for (UIScene* candidate in UIApplication.sharedApplication.connectedScenes) {
        if ([candidate isKindOfClass:UIWindowScene.class]
            && candidate.activationState != UISceneActivationStateUnattached) {
            return (UIWindowScene*)candidate;
        }
    }
    return nil;
}

void RunImportTask(NSString* status, const std::function<void()>& operation)
{
    UIWindow* host = [[UIWindow alloc] initWithWindowScene:ActiveWindowScene()];
    UIViewController* controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.055 alpha:1.0];
    host.rootViewController = controller;
    host.windowLevel = UIWindowLevelAlert;
    [host makeKeyAndVisible];

    UIActivityIndicatorView* activity = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    activity.translatesAutoresizingMaskIntoConstraints = NO;
    activity.color = [UIColor colorWithRed:0.88 green:0.62 blue:0.10 alpha:1.0];
    [activity startAnimating];

    UILabel* title = [UILabel new];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = L("import_progress_title");
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleTitle1];
    title.textColor = UIColor.whiteColor;
    title.textAlignment = NSTextAlignmentCenter;
    title.adjustsFontForContentSizeCategory = YES;
    title.numberOfLines = 0;

    UILabel* detail = [UILabel new];
    detail.translatesAutoresizingMaskIntoConstraints = NO;
    detail.text = status;
    detail.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    detail.textColor = [UIColor colorWithWhite:0.80 alpha:1.0];
    detail.textAlignment = NSTextAlignmentCenter;
    detail.adjustsFontForContentSizeCategory = YES;
    detail.numberOfLines = 0;

    UILabel* note = [UILabel new];
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.text = L("import_progress_note");
    note.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    note.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
    note.textAlignment = NSTextAlignmentCenter;
    note.adjustsFontForContentSizeCategory = YES;
    note.numberOfLines = 0;

    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[activity, title, detail, note]];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 18;
    [controller.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.centerYAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.centerYAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.leadingAnchor constant:36],
        [stack.trailingAnchor constraintEqualToAnchor:controller.view.safeAreaLayoutGuide.trailingAnchor constant:-36]
    ]];

    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, title);
    __block BOOL finished = NO;
    __block NSString* failure = nil;
    const std::function<void()> work = operation;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString* localFailure = nil;
        @autoreleasepool {
            try {
                work();
            } catch (const std::exception& error) {
                localFailure = @(error.what());
            } catch (...) {
                localFailure = L("error_unknown_import");
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            failure = localFailure;
            finished = YES;
        });
    });

    while (!finished) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    host.hidden = YES;
    if (failure) {
        throw std::runtime_error(failure.UTF8String);
    }
}

bool ShowImportError(NSString* error)
{
    __block BOOL finished = NO;
    __block BOOL retry = NO;
    UIWindow* host = [[UIWindow alloc] initWithWindowScene:ActiveWindowScene()];
    UIViewController* controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.055 alpha:1.0];
    host.rootViewController = controller;
    host.windowLevel = UIWindowLevelAlert;
    [host makeKeyAndVisible];

    NSString* help = [NSString stringWithFormat:L("import_help_format"), error];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:L("import_not_completed")
                                                                    message:help
                                                             preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L("later")
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction* action) {
        finished = YES;
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:L("retry")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
        retry = YES;
        finished = YES;
    }]];
    [controller presentViewController:alert animated:NO completion:nil];
    while (!finished) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    host.hidden = YES;
    return retry;
}

void ShowImportCompleted(void)
{
    __block BOOL finished = NO;
    UIWindow* host = [[UIWindow alloc] initWithWindowScene:ActiveWindowScene()];
    UIViewController* controller = [UIViewController new];
    controller.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.055 alpha:1.0];
    host.rootViewController = controller;
    host.windowLevel = UIWindowLevelAlert;
    [host makeKeyAndVisible];
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:L("import_complete")
        message:L("import_completed_message")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:L("start_game")
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
        finished = YES;
    }]];
    [controller presentViewController:alert animated:NO completion:nil];
    while (!finished) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                  beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    host.hidden = YES;
}

void ShowMessage(NSString* title, NSString* message)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, message);
        NSLog(@"Tiberian Dawn: %@: %@", title, message);
    });
}

UILabel* CompactWarningLabel()
{
    static UILabel* label = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        label = [UILabel new];
        label.text = L("compact_warning");
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 2;
        label.textColor = UIColor.whiteColor;
        label.backgroundColor = [UIColor colorWithRed:0.45 green:0.08 blue:0.06 alpha:0.94];
        label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
        label.adjustsFontForContentSizeCategory = YES;
        label.isAccessibilityElement = YES;
        label.accessibilityTraits = UIAccessibilityTraitStaticText;
        label.hidden = YES;
    });
    return label;
}
}

int TiberianDawn_GetLanguagePreference(void)
{
    return StoredLanguagePreference();
}

int TiberianDawn_GetEffectiveLanguage(void)
{
    return static_cast<int>(EffectiveLanguage());
}

void TiberianDawn_CycleLanguagePreference(void)
{
    const int next = (StoredLanguagePreference() + 1) % 3;
    [[NSUserDefaults standardUserDefaults] setInteger:next forKey:LanguagePreferenceKey];
}

const char* TiberianDawn_LocalizedText(const char* key)
{
    return IPad_Localized_Text(EffectiveLanguage(), key);
}

const char* TiberianDawn_LanguagePreferenceLabel(void)
{
    switch (StoredLanguagePreference()) {
    case IPAD_LANGUAGE_GERMAN:
        return TiberianDawn_LocalizedText("language_german");
    case IPAD_LANGUAGE_ENGLISH:
        return TiberianDawn_LocalizedText("language_english");
    default:
        return TiberianDawn_LocalizedText("language_system");
    }
}

const char* TiberianDawn_ClassicLanguageExtension(void)
{
    return EffectiveLanguage() == IPAD_EFFECTIVE_GERMAN ? "GER" : "ENG";
}

void TiberianDawn_ShowTouchControls(bool force)
{
    @autoreleasepool {
        NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
        if (!force && [defaults boolForKey:TouchGuideShownKey]) return;

        void (^present)(void) = ^{
            UIWindowScene* scene = ActiveWindowScene();
            if (!scene) return;

            __block BOOL finished = NO;
            UIWindow* host = [[UIWindow alloc] initWithWindowScene:scene];
            UIViewController* controller = [UIViewController new];
            controller.view.backgroundColor = [UIColor colorWithRed:0.035 green:0.055 blue:0.055 alpha:1.0];
            host.rootViewController = controller;
            host.windowLevel = UIWindowLevelAlert;
            [host makeKeyAndVisible];

            UIAlertController* alert = [UIAlertController alertControllerWithTitle:L("touch_help_title")
                                                                            message:L("touch_help_message")
                                                                     preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:L("ok")
                                                  style:UIAlertActionStyleDefault
                                                handler:^(UIAlertAction* action) {
                finished = YES;
            }]];
            [controller presentViewController:alert animated:NO completion:nil];
            UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, alert.view);
            while (!finished) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
            [defaults setBool:YES forKey:TouchGuideShownKey];
            host.hidden = YES;
        };

        if (NSThread.isMainThread) {
            present();
        } else {
            dispatch_sync(dispatch_get_main_queue(), present);
        }
    }
}

bool TiberianDawn_PrepareGameData(void)
{
    @autoreleasepool {
        TiberianDawn_ConfigureAudioSession();
        NSURL* destination = LibraryDataURL();
        if (ValidData(destination)) {
            ExcludeFromBackup(destination);
            TiberianDawn_ShowTouchControls(false);
            return true;
        }

        NSFileManager* manager = [NSFileManager defaultManager];
        NSURL* parent = [destination URLByDeletingLastPathComponent];
        [manager createDirectoryAtURL:parent withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL* staging = [parent URLByAppendingPathComponent:@"vanillatd.importing" isDirectory:YES];
        [manager removeItemAtURL:staging error:nil];

        // Private packages may include user-supplied game data. Install only
        // when no complete installation exists; use the same staged importer.
        NSURL* bundled = [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"GameData"];
        if (ValidData(bundled)) {
            try {
                RunImportTask(L("migration_status"), [&] {
                    EnsureImportCapacity(parent);
                    CopyPreparedDirectory(bundled, staging);
                    if (!ValidData(staging)) throw std::runtime_error("Bundled game data is incomplete");
                    AtomicInstall(staging, destination);
                });
                ExcludeFromBackup(destination);
                return true;
            } catch (const std::exception&) {
                [manager removeItemAtURL:staging error:nil];
                // Fall through to the normal user-selectable import workflow.
            }
        }

        NSURL* legacy = LegacyDataURL();
        while (ValidData(legacy)) {
            try {
                RunImportTask(L("migration_status"), [&] {
                    EnsureImportCapacity(parent);
                    [manager removeItemAtURL:staging error:nil];
                    CopyPreparedDirectory(legacy, staging);
                    if (!ValidData(staging)) throw std::runtime_error(L("error_migration_incomplete").UTF8String);
                    AtomicInstall(staging, destination);
                    // Remove only immutable assets after the verified copy. Saves and INI files remain visible in Documents.
                    NSArray<NSString*>* assets = [manager contentsOfDirectoryAtPath:legacy.path error:nil];
                    for (NSString* name in assets) {
                        if ([name.pathExtension caseInsensitiveCompare:@"MIX"] == NSOrderedSame
                            || [name caseInsensitiveCompare:@"gdi"] == NSOrderedSame
                            || [name caseInsensitiveCompare:@"nod"] == NSOrderedSame) {
                            [manager removeItemAtURL:[legacy URLByAppendingPathComponent:name] error:nil];
                        }
                    }
                });
                TiberianDawn_ShowTouchControls(false);
                return true;
            } catch (const std::exception& error) {
                [manager removeItemAtURL:staging error:nil];
                if (!ShowImportError(@(error.what()))) return false;
            }
        }

        while (true) {
            NSArray<NSURL*>* selected = PickSources();
            if (selected.count == 0) return false;
            try {
                RunImportTask(L("import_sources_status"), [&] {
                    EnsureImportCapacity(parent);
                    [manager removeItemAtURL:staging error:nil];
                    NSURL* first = selected.firstObject;
                    NSNumber* directory = nil;
                    [first getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
                    if (selected.count == 1 && directory.boolValue) {
                        const bool accessed = [first startAccessingSecurityScopedResource];
                        try {
                            CopyPreparedDirectory(first, staging);
                        } catch (...) {
                            if (accessed) [first stopAccessingSecurityScopedResource];
                            throw;
                        }
                        if (accessed) [first stopAccessingSecurityScopedResource];
                    } else {
                        ExtractISOs(selected, staging);
                    }
                    if (!ValidData(staging)) {
                        throw std::runtime_error(L("error_sources_incomplete").UTF8String);
                    }
                    AtomicInstall(staging, destination);
                });
                ShowImportCompleted();
                TiberianDawn_ShowTouchControls(false);
                return true;
            } catch (const std::exception& error) {
                [manager removeItemAtURL:staging error:nil];
                if (!ShowImportError(@(error.what()))) return false;
            }
        }
    }
}

void TiberianDawn_ManageSaveGames(void)
{
    @autoreleasepool {
        void (^present)(void) = ^{
            TiberianDawnSaveManagerController* controller = [TiberianDawnSaveManagerController new];
            UIWindow* host = [[UIWindow alloc] initWithWindowScene:ActiveWindowScene()];
            host.rootViewController = controller;
            host.windowLevel = UIWindowLevelAlert;
            [host makeKeyAndVisible];
            while (!controller.finished) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            }
            host.hidden = YES;
        };
        if (NSThread.isMainThread) {
            present();
        } else {
            dispatch_sync(dispatch_get_main_queue(), present);
        }
    }
}

void TiberianDawn_ConfigureAudioSession(void)
{
    @autoreleasepool {
        AVAudioSession* session = AVAudioSession.sharedInstance;
        NSError* error = nil;
        [session setCategory:AVAudioSessionCategoryAmbient
                        mode:AVAudioSessionModeDefault
                     options:AVAudioSessionCategoryOptionAllowBluetoothA2DP
                       error:&error];
        [session setActive:YES error:&error];

        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSNotificationCenter* center = NSNotificationCenter.defaultCenter;
            [center addObserverForName:AVAudioSessionInterruptionNotification object:session queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification* note) {
                const NSInteger type = [note.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
                SDL_Event event = {};
                event.type = SDL_USEREVENT;
                event.user.code = type == AVAudioSessionInterruptionTypeBegan ? IPADOS_EVENT_AUDIO_PAUSE : IPADOS_EVENT_AUDIO_RESUME;
                SDL_PushEvent(&event);
            }];
            [center addObserverForName:AVAudioSessionRouteChangeNotification object:session queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification* note) {
                SDL_Event event = {};
                event.type = SDL_USEREVENT;
                event.user.code = IPADOS_EVENT_AUDIO_ROUTE_CHANGED;
                SDL_PushEvent(&event);
            }];
            [center addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:session queue:NSOperationQueue.mainQueue
                            usingBlock:^(NSNotification* note) {
                TiberianDawn_ConfigureAudioSession();
                SDL_Event event = {};
                event.type = SDL_USEREVENT;
                event.user.code = IPADOS_EVENT_AUDIO_RESET;
                SDL_PushEvent(&event);
            }];
        });
    }
}

bool TiberianDawn_RebuildAudioEngine(void)
{
    return IPad_Audio_Rebuild();
}

void TiberianDawn_SetCompactWindowWarning(bool visible)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UILabel* label = CompactWarningLabel();
        label.text = L("compact_warning");
        UIWindow* window = nil;
        for (UIScene* connectedScene in UIApplication.sharedApplication.connectedScenes) {
            if (![connectedScene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene* scene = (UIWindowScene*)connectedScene;
            for (UIWindow* candidate in scene.windows) {
                if (!window) window = candidate;
                if (candidate.isKeyWindow) {
                    window = candidate;
                    break;
                }
            }
            if (window.isKeyWindow) break;
        }
        if (visible && window && label.superview != window) {
            [label removeFromSuperview];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            [window addSubview:label];
            [NSLayoutConstraint activateConstraints:@[
                [label.leadingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.leadingAnchor constant:12],
                [label.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-12],
                [label.topAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.topAnchor constant:12]
            ]];
        }
        if (label.hidden == visible) {
            label.hidden = !visible;
            if (visible) UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, label.text);
        }
    });
}
