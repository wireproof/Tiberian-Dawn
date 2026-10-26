#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include "macos_platform.h"
#include "common/ipados_audio_engine.h"
#include "common/ipados_localization.h"
#include "third_party/unshieldv3/ISArchiveV3.h"

#include <algorithm>
#include <cctype>
#include <cstring>
#include <fstream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

namespace
{
NSString* Text(NSString* german, NSString* english)
{
    NSString* language = NSLocale.preferredLanguages.firstObject.lowercaseString;
    return [language hasPrefix:@"de"] ? german : english;
}

NSURL* GameDataURL()
{
    NSURL* support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                           inDomains:NSUserDomainMask].firstObject;
    return [[[support URLByAppendingPathComponent:@"Tiberian Dawn" isDirectory:YES]
        URLByAppendingPathComponent:@"Game Data" isDirectory:YES]
        URLByAppendingPathComponent:@"vanillatd" isDirectory:YES];
}

NSURL* UserDataURL()
{
    NSURL* support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory
                                                           inDomains:NSUserDomainMask].firstObject;
    return [[[support URLByAppendingPathComponent:@"Tiberian Dawn" isDirectory:YES]
        URLByAppendingPathComponent:@"User Data" isDirectory:YES]
        URLByAppendingPathComponent:@"vanillatd" isDirectory:YES];
}

const char* const LanguagePreferenceKey = "TiberianDawnLanguagePreference";

int StoredLanguagePreference()
{
    const NSInteger value = [NSUserDefaults.standardUserDefaults integerForKey:@(LanguagePreferenceKey)];
    return value >= IPAD_LANGUAGE_SYSTEM && value <= IPAD_LANGUAGE_ENGLISH
        ? static_cast<int>(value)
        : IPAD_LANGUAGE_SYSTEM;
}

IPadLanguage EffectiveLanguage()
{
    NSString* language = NSLocale.preferredLanguages.firstObject ?: @"en";
    return Resolve_IPad_Language(StoredLanguagePreference(), language.UTF8String);
}

bool Exists(NSURL* directory, NSString* relative)
{
    return [NSFileManager.defaultManager fileExistsAtPath:[directory URLByAppendingPathComponent:relative].path];
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
        if (!Exists(directory, file)) return false;
    }
    return true;
}

uint32_t ReadLE32(const unsigned char* value)
{
    return static_cast<uint32_t>(value[0]) | (static_cast<uint32_t>(value[1]) << 8)
           | (static_cast<uint32_t>(value[2]) << 16) | (static_cast<uint32_t>(value[3]) << 24);
}

std::string Upper(std::string value)
{
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::toupper(c));
    });
    return value;
}

class ISO9660
{
public:
    struct Entry
    {
        uint32_t extent;
        uint32_t size;
        bool directory;
    };

    explicit ISO9660(const std::string& path) : filePath(path), stream(path.c_str(), std::ios::binary)
    {
        if (!stream) throw std::runtime_error("ISO could not be opened");
        std::vector<unsigned char> pvd(2048);
        stream.seekg(16 * 2048, std::ios::beg);
        stream.read(reinterpret_cast<char*>(pvd.data()), pvd.size());
        if (stream.gcount() != static_cast<std::streamsize>(pvd.size()) || pvd[0] != 1
            || std::memcmp(pvd.data() + 1, "CD001", 5) != 0) {
            throw std::runtime_error("The selected file is not an ISO 9660 disc image");
        }
        volume.assign(reinterpret_cast<char*>(pvd.data() + 40), 32);
        while (!volume.empty() && volume.back() == ' ') volume.pop_back();
        const unsigned char* root = pvd.data() + 156;
        ReadDirectory(ReadLE32(root + 2), ReadLE32(root + 10), "", 0);
    }

    const std::string& Volume() const { return volume; }
    bool Has(const std::string& path) const { return entries.find(Upper(path)) != entries.end(); }

    void Extract(const std::string& source, const std::string& destination) const
    {
        std::map<std::string, Entry>::const_iterator it = entries.find(Upper(source));
        if (it == entries.end() || it->second.directory) throw std::runtime_error("CD file is missing: " + source);
        std::ifstream input(filePath.c_str(), std::ios::binary);
        input.seekg(static_cast<std::streamoff>(it->second.extent) * 2048, std::ios::beg);
        std::ofstream output(destination.c_str(), std::ios::binary | std::ios::trunc);
        std::vector<char> buffer(1024 * 1024);
        uint32_t remaining = it->second.size;
        while (remaining > 0) {
            const std::streamsize count = std::min<uint32_t>(remaining, buffer.size());
            input.read(buffer.data(), count);
            if (input.gcount() != count) throw std::runtime_error("The CD image could not be read completely");
            output.write(buffer.data(), count);
            remaining -= static_cast<uint32_t>(count);
        }
        if (!output) throw std::runtime_error("An extracted file could not be written");
    }

private:
    void ReadDirectory(uint32_t extent, uint32_t size, const std::string& prefix, int depth)
    {
        if (depth > 4 || size == 0 || size > 32 * 1024 * 1024) return;
        std::vector<unsigned char> data(size);
        stream.seekg(static_cast<std::streamoff>(extent) * 2048, std::ios::beg);
        stream.read(reinterpret_cast<char*>(data.data()), size);
        size_t offset = 0;
        while (offset < data.size()) {
            const unsigned char recordLength = data[offset];
            if (recordLength == 0) {
                offset = ((offset / 2048) + 1) * 2048;
                continue;
            }
            if (offset + recordLength > data.size() || recordLength < 34) break;
            const unsigned char* record = data.data() + offset;
            const unsigned char nameLength = record[32];
            if (33 + nameLength <= recordLength && !(nameLength == 1 && (record[33] == 0 || record[33] == 1))) {
                std::string name(reinterpret_cast<const char*>(record + 33), nameLength);
                const size_t version = name.find(';');
                if (version != std::string::npos) name.erase(version);
                const std::string path = prefix.empty() ? name : prefix + "/" + name;
                Entry entry = {ReadLE32(record + 2), ReadLE32(record + 10), (record[25] & 2) != 0};
                entries[Upper(path)] = entry;
                if (entry.directory && (depth == 0 || Upper(path) == "INSTALL")) {
                    ReadDirectory(entry.extent, entry.size, path, depth + 1);
                }
            }
            offset += recordLength;
        }
    }

    std::string filePath;
    std::ifstream stream;
    std::string volume;
    std::map<std::string, Entry> entries;
};

void EnsureCapacity(NSURL* parent)
{
    NSDictionary* attributes = [NSFileManager.defaultManager attributesOfFileSystemForPath:parent.path error:nil];
    const unsigned long long available = [attributes[NSFileSystemFreeSize] unsignedLongLongValue];
    const unsigned long long required = 1200ULL * 1024ULL * 1024ULL;
    if (available > 0 && available < required) {
        throw std::runtime_error("At least 1.2 GB of free space is required for a safe import");
    }
}

void WriteBytes(const std::vector<uint8_t>& bytes, const std::string& path)
{
    std::ofstream output(path.c_str(), std::ios::binary | std::ios::trunc);
    if (!bytes.empty()) output.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
    if (!output) throw std::runtime_error("An installer file could not be written");
}

void ExtractSetupFiles(const std::string& setupPath, NSURL* staging)
{
    ISArchiveV3 archive(setupPath);
    const char* names[] = {"CCLOCAL.MIX", "DESEICNH.MIX", "LOCAL.MIX", "SPEECH.MIX", "TEMPICNH.MIX",
                           "TRANSIT.MIX", "UPDATE.MIX", "UPDATEC.MIX", "WINTICNH.MIX"};
    for (const char* name : names) {
        const std::string archived = std::string("C&C95\\") + name;
        if (archive.exists(archived)) {
            WriteBytes(archive.decompress(archived), [staging URLByAppendingPathComponent:@(name)].fileSystemRepresentation);
        }
    }
}

void ExtractISOs(NSArray<NSURL*>* urls, NSURL* staging)
{
    NSFileManager* manager = NSFileManager.defaultManager;
    [manager createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:nil];
    [manager createDirectoryAtURL:[staging URLByAppendingPathComponent:@"gdi" isDirectory:YES]
      withIntermediateDirectories:YES attributes:nil error:nil];
    [manager createDirectoryAtURL:[staging URLByAppendingPathComponent:@"nod" isDirectory:YES]
      withIntermediateDirectories:YES attributes:nil error:nil];

    bool haveGDI = false;
    bool haveNod = false;
    bool setupDone = false;
    const char* common[] = {"CONQUER.MIX", "SOUNDS.MIX", "DESERT.MIX", "TEMPERAT.MIX", "WINTER.MIX"};
    const char* faction[] = {"GENERAL.MIX", "MOVIES.MIX", "SCORES.MIX"};
    for (NSURL* url in urls) {
        ISO9660 iso(url.fileSystemRepresentation);
        const std::string volume = Upper(iso.Volume());
        NSString* side = volume.find("GDI") != std::string::npos ? @"gdi"
            : (volume.find("NOD") != std::string::npos ? @"nod" : nil);
        if (side == nil) throw std::runtime_error("One selected disc is neither the GDI95 nor the NOD95 Gold CD");
        haveGDI = haveGDI || [side isEqualToString:@"gdi"];
        haveNod = haveNod || [side isEqualToString:@"nod"];
        for (const char* name : common) {
            NSURL* destination = [staging URLByAppendingPathComponent:@(name)];
            if (iso.Has(name) && ![manager fileExistsAtPath:destination.path]) {
                iso.Extract(name, destination.fileSystemRepresentation);
            }
        }
        for (const char* name : faction) {
            NSURL* destination = [[staging URLByAppendingPathComponent:side] URLByAppendingPathComponent:@(name)];
            iso.Extract(name, destination.fileSystemRepresentation);
        }
        if (!setupDone && iso.Has("INSTALL/SETUP.Z")) {
            NSURL* setup = [[staging URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"SETUP.Z"];
            iso.Extract("INSTALL/SETUP.Z", setup.fileSystemRepresentation);
            ExtractSetupFiles(setup.fileSystemRepresentation, staging);
            [manager removeItemAtURL:setup error:nil];
            setupDone = true;
        }
    }
    if (!haveGDI || !haveNod) throw std::runtime_error("Select the GDI and Nod Gold CD images together");
}

void CopyPreparedDirectory(NSURL* source, NSURL* staging)
{
    NSFileManager* manager = NSFileManager.defaultManager;
    [manager createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:nil];
    NSError* listingError = nil;
    NSArray<NSURL*>* rootItems = [manager contentsOfDirectoryAtURL:source
                                        includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                           options:NSDirectoryEnumerationSkipsHiddenFiles
                                                             error:&listingError];
    if (!rootItems) throw std::runtime_error(listingError.localizedDescription.UTF8String);
    for (NSURL* item in rootItems) {
        NSNumber* isDirectory = nil;
        [item getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
        NSString* name = item.lastPathComponent;
        if (isDirectory.boolValue
            && ([name caseInsensitiveCompare:@"gdi"] == NSOrderedSame
                || [name caseInsensitiveCompare:@"nod"] == NSOrderedSame)) {
            NSURL* destination = [staging URLByAppendingPathComponent:name.lowercaseString isDirectory:YES];
            [manager createDirectoryAtURL:destination withIntermediateDirectories:YES attributes:nil error:nil];
            for (NSURL* sideItem in [manager contentsOfDirectoryAtURL:item
                                           includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                              options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                error:nil]) {
                if ([sideItem.pathExtension caseInsensitiveCompare:@"MIX"] != NSOrderedSame) continue;
                NSError* error = nil;
                if (![manager copyItemAtURL:sideItem
                                      toURL:[destination URLByAppendingPathComponent:sideItem.lastPathComponent.uppercaseString]
                                      error:&error]) {
                    throw std::runtime_error(error.localizedDescription.UTF8String);
                }
            }
        } else if (!isDirectory.boolValue && [item.pathExtension caseInsensitiveCompare:@"MIX"] == NSOrderedSame) {
            NSError* error = nil;
            if (![manager copyItemAtURL:item
                                  toURL:[staging URLByAppendingPathComponent:name.uppercaseString]
                                  error:&error]) {
                throw std::runtime_error(error.localizedDescription.UTF8String);
            }
        }
    }
}

void AtomicInstall(NSURL* staging, NSURL* destination)
{
    NSFileManager* manager = NSFileManager.defaultManager;
    NSURL* parent = destination.URLByDeletingLastPathComponent;
    [manager createDirectoryAtURL:parent withIntermediateDirectories:YES attributes:nil error:nil];
    NSURL* previous = [parent URLByAppendingPathComponent:@"vanillatd.previous" isDirectory:YES];
    [manager removeItemAtURL:previous error:nil];
    if ([manager fileExistsAtPath:destination.path] && ![manager moveItemAtURL:destination toURL:previous error:nil]) {
        throw std::runtime_error("Existing game data could not be moved aside safely");
    }
    NSError* installError = nil;
    if (![manager moveItemAtURL:staging toURL:destination error:&installError]) {
        [manager moveItemAtURL:previous toURL:destination error:nil];
        throw std::runtime_error(installError.localizedDescription.UTF8String);
    }
    [manager removeItemAtURL:previous error:nil];
}

bool ShowGuide()
{
    NSAlert* alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = Text(@"Original-Spieldaten importieren", @"Import original game data");
    alert.informativeText = Text(
        @"Tiberian Dawn enthält aus rechtlichen Gründen keine Originaldaten. Wähle deine GDI- und Nod-C&C-Gold-ISOs gemeinsam oder nacheinander aus. Alternativ kannst du einen bereits vorbereiteten vanillatd-Ordner auswählen. Die Dateien werden nur lokal gelesen und installiert.",
        @"Tiberian Dawn contains no original game data for legal reasons. Select your GDI and Nod C&C Gold ISOs together or one after the other. Alternatively, select one prepared vanillatd folder. Files are read and installed locally only.");
    [alert addButtonWithTitle:Text(@"Spieldaten auswählen", @"Select game data")];
    [alert addButtonWithTitle:Text(@"Später", @"Later")];
    return [alert runModal] == NSAlertFirstButtonReturn;
}

NSArray<NSURL*>* PickSources()
{
    NSOpenPanel* picker = [NSOpenPanel openPanel];
    picker.title = Text(@"GDI und Nod auswählen", @"Select GDI and Nod");
    picker.message = Text(@"Wähle beide Gold-ISOs, die erste ISO oder genau einen vorbereiteten vanillatd-Ordner.",
                          @"Select both Gold ISOs, the first ISO, or exactly one prepared vanillatd folder.");
    picker.canChooseFiles = YES;
    picker.canChooseDirectories = YES;
    picker.allowsMultipleSelection = YES;
    picker.resolvesAliases = YES;
    picker.allowedContentTypes = @[UTTypeDiskImage];
    return [picker runModal] == NSModalResponseOK ? picker.URLs : @[];
}

NSArray<NSURL*>* PickCompanionISO(NSURL* first)
{
    NSOpenPanel* picker = [NSOpenPanel openPanel];
    picker.title = Text(@"Zweite Gold-CD auswählen", @"Select the second Gold CD");
    picker.message = Text(@"Wähle jetzt die andere ISO: GDI oder Nod.",
                          @"Now select the other ISO: GDI or Nod.");
    picker.canChooseFiles = YES;
    picker.canChooseDirectories = NO;
    picker.allowsMultipleSelection = NO;
    picker.resolvesAliases = YES;
    picker.allowedContentTypes = @[UTTypeDiskImage];
    picker.directoryURL = first.URLByDeletingLastPathComponent;
    return [picker runModal] == NSModalResponseOK ? picker.URLs : @[];
}

bool RetryAfterError(const std::exception& error)
{
    NSAlert* alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = Text(@"Import nicht abgeschlossen", @"Import not completed");
    alert.informativeText = [NSString stringWithFormat:Text(
        @"%s\n\nPrüfe, ob du die GDI- und Nod-Gold-ISO gemeinsam ausgewählt hast und mindestens 1,2 GB frei sind.",
        @"%s\n\nCheck that you selected the GDI and Nod Gold ISOs together and have at least 1.2 GB free."), error.what()];
    [alert addButtonWithTitle:Text(@"Erneut versuchen", @"Try again")];
    [alert addButtonWithTitle:Text(@"Später", @"Later")];
    return [alert runModal] == NSAlertFirstButtonReturn;
}

void ShowCompleted()
{
    NSAlert* alert = [NSAlert new];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = Text(@"Import abgeschlossen", @"Import completed");
    alert.informativeText = Text(
        @"Die GDI- und Nod-Daten wurden geprüft und lokal installiert. Das Spiel wird jetzt gestartet.",
        @"The GDI and Nod data was validated and installed locally. The game will now start.");
    [alert addButtonWithTitle:Text(@"Spiel starten", @"Start game")];
    [alert runModal];
}
} // namespace

bool TiberianDawn_PrepareGameData(void)
{
    @autoreleasepool {
        NSURL* destination = GameDataURL();
        if (ValidData(destination)) return true;

        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        // The importer runs before SDL initializes Cocoa. Complete AppKit's
        // launch sequence explicitly so its modal panels are visible and
        // accessible even on a pristine first start.
        [NSApp finishLaunching];
        [NSApp activateIgnoringOtherApps:YES];

        NSFileManager* manager = NSFileManager.defaultManager;
        NSURL* parent = destination.URLByDeletingLastPathComponent;
        [manager createDirectoryAtURL:parent withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL* previous = [parent URLByAppendingPathComponent:@"vanillatd.previous" isDirectory:YES];
        if (!ValidData(destination) && ValidData(previous)) {
            // Recover the last complete install if an earlier replacement was
            // interrupted after moving it aside.
            [manager removeItemAtURL:destination error:nil];
            NSError* recoveryError = nil;
            if ([manager moveItemAtURL:previous toURL:destination error:&recoveryError]) return true;
            NSAlert* alert = [NSAlert new];
            alert.alertStyle = NSAlertStyleCritical;
            alert.messageText = Text(@"Spieldaten konnten nicht wiederhergestellt werden",
                                     @"Game data could not be recovered");
            alert.informativeText = recoveryError.localizedDescription;
            [alert addButtonWithTitle:@"OK"];
            [alert runModal];
            return false;
        }
        NSURL* staging = [parent URLByAppendingPathComponent:@"vanillatd.importing" isDirectory:YES];
        [manager removeItemAtURL:staging error:nil];

        // Match iOS: optional private bundled data never replaces a complete install.
        NSURL* bundled = [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:@"GameData"];
        if (ValidData(bundled)) {
            try {
                EnsureCapacity(parent);
                CopyPreparedDirectory(bundled, staging);
                if (!ValidData(staging)) throw std::runtime_error("Bundled game data is incomplete");
                AtomicInstall(staging, destination);
                return true;
            } catch (const std::exception&) {
                [manager removeItemAtURL:staging error:nil];
            }
        }

        while (ShowGuide()) {
            NSArray<NSURL*>* selected = PickSources();
            if (selected.count == 0) continue;
            try {
                EnsureCapacity(parent);
                [manager removeItemAtURL:staging error:nil];
                NSURL* first = selected.firstObject;
                NSNumber* isDirectory = nil;
                [first getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
                if (selected.count == 1 && !isDirectory.boolValue) {
                    NSArray<NSURL*>* companion = PickCompanionISO(first);
                    if (companion.count == 0) continue;
                    selected = [selected arrayByAddingObjectsFromArray:companion];
                }
                if (selected.count == 1 && isDirectory.boolValue) {
                    CopyPreparedDirectory(first, staging);
                } else {
                    ExtractISOs(selected, staging);
                }
                if (!ValidData(staging)) {
                    throw std::runtime_error("The selected sources do not contain all required C&C Gold files");
                }
                AtomicInstall(staging, destination);
                ShowCompleted();
                return true;
            } catch (const std::exception& error) {
                [manager removeItemAtURL:staging error:nil];
                if (!RetryAfterError(error)) return false;
            }
        }
        return false;
    }
}

void TiberianDawn_ConfigureAudioSession(void)
{
    IPad_Audio_Resume();
}

bool TiberianDawn_RebuildAudioEngine(void)
{
    return IPad_Audio_Rebuild();
}

void TiberianDawn_SetCompactWindowWarning(bool visible)
{
    (void)visible;
}

void TiberianDawn_ManageSaveGames(void)
{
    @autoreleasepool {
        NSURL* directory = UserDataURL();
        [NSFileManager.defaultManager createDirectoryAtURL:directory
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
        NSAlert* alert = [NSAlert new];
        alert.alertStyle = NSAlertStyleInformational;
        alert.messageText = Text(@"Spielstände und Dateien", @"Save games and files");
        alert.informativeText = Text(
            @"Der Spielstandordner wird im Finder geöffnet. Dort kannst du SAVEGAME-Dateien sicher kopieren, nach iCloud Drive ziehen oder von dort einsetzen. Vorhandene Dateien werden nicht automatisch überschrieben.",
            @"The save-game folder will open in Finder. You can safely copy SAVEGAME files, move them to iCloud Drive, or restore them from there. Existing files are not overwritten automatically.");
        [alert addButtonWithTitle:Text(@"Im Finder öffnen", @"Open in Finder")];
        [alert addButtonWithTitle:Text(@"Abbrechen", @"Cancel")];
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[directory]];
        }
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
    [NSUserDefaults.standardUserDefaults setInteger:next forKey:@(LanguagePreferenceKey)];
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

void TiberianDawn_GetSafeAreaInsets(void* window,
                                   int output_width,
                                   int output_height,
                                   int* left,
                                   int* top,
                                   int* right,
                                   int* bottom)
{
    (void)window;
    (void)output_width;
    (void)output_height;
    if (left) *left = 0;
    if (top) *top = 0;
    if (right) *right = 0;
    if (bottom) *bottom = 0;
}

int TiberianDawn_IsLowPowerModeEnabled(void)
{
    if (@available(macOS 12.0, *)) {
        return NSProcessInfo.processInfo.lowPowerModeEnabled ? 1 : 0;
    }
    return 0;
}

int TiberianDawn_GetThermalState(void)
{
    return static_cast<int>(NSProcessInfo.processInfo.thermalState);
}
