#include "ipados_localization.h"

#include <cctype>
#include <cstring>

namespace
{
struct Translation
{
    const char* key;
    const char* english;
    const char* german;
};

// Text used by the 1995 renderer deliberately stays ASCII. Native UIKit text
// uses UTF-8 and can therefore retain German punctuation and umlauts.
const Translation Translations[] = {
    {"main_saves", "Save Games / Files", "Spielstaende / Dateien"},
    {"main_multiplayer", "Multiplayer", "Mehrspieler"},
    {"main_multiplayer_unavailable", "Multiplayer: unavailable", "Multiplayer: nicht verfuegbar"},
    {"multiplayer_title", "Multiplayer", "Mehrspieler"},
    {"multiplayer_explanation", "Play on the same local network or use an encrypted private Internet room. All players need this same app version and their own matching game data.", "Spiele im selben lokalen Netzwerk oder ueber einen verschluesselten privaten Internet-Raum. Alle Spieler brauchen dieselbe App-Version und eigene, identische Spieldaten."},
    {"multiplayer_local", "Local Network", "Lokales Netzwerk"},
    {"multiplayer_create", "Create Private Internet Room", "Privaten Internet-Raum erstellen"},
    {"multiplayer_join", "Join Internet Invitation", "Internet-Einladung beitreten"},
    {"multiplayer_skirmish", "Skirmish vs. AI", "Gefecht gegen KI"},
    {"multiplayer_invite_prompt", "Paste the complete invitation from the host. It contains the six-character room code and a private secret.", "Fuege die vollstaendige Einladung des Hosts ein. Sie enthaelt den sechsstelligen Raumcode und ein privates Geheimnis."},
    {"multiplayer_connect", "Connect", "Verbinden"},
    {"multiplayer_connection_failed", "Connection Failed", "Verbindung fehlgeschlagen"},
    {"multiplayer_room_ready", "Private Room Ready", "Privater Raum bereit"},
    {"multiplayer_room_ready_format", "Invitation copied to the clipboard:\n\n%@\n\nShare it privately. Continue, then choose New Game in the classic lobby.", "Einladung wurde kopiert:\n\n%@\n\nTeile sie privat. Fahre fort und waehle danach Neues Spiel in der klassischen Lobby."},
    {"battery_format", "Battery mode: %s", "Batteriemodus: %s"},
    {"state_on", "ON", "AN"},
    {"state_off", "OFF", "AUS"},
    {"controller_layout", "Controller layout", "Controller-Belegung"},
    {"language_system", "Language: System", "Sprache: System"},
    {"language_german", "Language: German", "Sprache: Deutsch"},
    {"language_english", "Language: English", "Sprache: Englisch"},
    {"language_restart_notice",
     "Language saved. Classic menus change after Exit Game and reopening the app. German original text is used when available; otherwise English remains active.",
     "Sprache gespeichert. Klassische Menues wechseln nach Exit Game und erneutem Oeffnen der App. Deutsche Originaltexte werden verwendet, wenn sie vorhanden sind; sonst bleibt Englisch aktiv."},
    {"visual_image_format", "Image: %s", "Bild: %s"},
    {"visual_artwork_format", "Style: %s", "Stil: %s"},
    {"visual_ui_format", "Touch size: %d%%", "Touch-Groesse: %d%%"},
    {"visual_readability_format", "Readability: %s", "Lesbarkeit: %s"},
    {"visual_mode_sharp", "Sharp", "Scharf"},
    {"visual_mode_pixel", "Pixel-perfect", "Pixelgenau"},
    {"visual_mode_classic", "Classic", "Klassisch"},
    {"visual_artwork_original", "Original", "Original"},
    {"visual_artwork_modern", "Modern", "Modern"},
    {"visual_readability_high", "High", "Hoch"},
    {"visual_readability_normal", "Normal", "Normal"},
    {"touch_edge_scroll_format", "Edge scroll: %s", "Randscrollen: %s"},
    {"touch_scroll_speed_format", "Touch scroll: %s", "Touch-Tempo: %s"},
    {"touch_selection_format", "Selection: %s", "Auswahl: %s"},
    {"touch_help_button", "Touch controls", "Touch-Steuerung"},
    {"touch_help_title", "Touch Controls", "Touch-Steuerung"},
    {"touch_help_message",
     "Tap: select or issue a command\nDrag one finger on terrain: select several units\nDrag two fingers: move the map\nDrag a selection to an edge: continue scrolling\nPress and hold or tap with two fingers: cancel / right click\n\nApple Pencil: precise selection; double-tap: cancel / right click\nPencil Pro squeeze: back; hold squeeze and move: pan the map\n\nPinch no longer changes the interface during play. UI scale remains available in Visual Controls.",
     "Tippen: auswählen oder Befehl geben\nMit einem Finger über Gelände ziehen: mehrere Einheiten auswählen\nMit zwei Fingern ziehen: Karte verschieben\nAuswahl bis an den Rand ziehen: automatisch weiterscrollen\nLange drücken oder mit zwei Fingern tippen: Abbrechen / Rechtsklick\n\nApple Pencil: präzise Auswahl; Doppeltipp: Abbrechen / Rechtsklick\nPencil Pro drücken: Zurück; gedrückt bewegen: Karte verschieben\n\nPinch verändert die Oberfläche nicht mehr während des Spiels. Die UI-Skalierung bleibt in den visuellen Einstellungen verfügbar."},
    {"vision_look_scroll_format", "Gaze scroll: %s", "Blickscrollen: %s"},
    {"vision_scroll_speed_format", "Scroll: %s", "Tempo: %s"},
    {"vision_edge_format", "Edge: %s", "Rand: %s"},
    {"vision_selection_format", "Selection: %s", "Auswahl: %s"},
    {"vision_level_slow", "Slow", "Langsam"},
    {"vision_level_balanced", "Balanced", "Mittel"},
    {"vision_level_fast", "Fast", "Schnell"},
    {"vision_level_narrow", "Narrow", "Schmal"},
    {"vision_level_wide", "Wide", "Breit"},
    {"vision_level_precise", "Precise", "Praezise"},
    {"vision_level_forgiving", "Forgiving", "Tolerant"},
    {"controller_none",
     "Controllers are detected automatically.\nLeft stick: pointer  Right stick: map\nConnect a controller to start using it.",
     "Controller werden automatisch erkannt.\nLinker Stick: Zeiger  Rechter Stick: Karte\nVerbinde einen Controller, um sofort zu spielen."},
    {"controller_playstation",
     "PlayStation\nCross: Select  Circle: Cancel\nSquare: Guard  Triangle: Formation\nL1/R1: Ctrl/Alt  Options: Confirm",
     "PlayStation\nKreuz: Auswaehlen  Kreis: Abbrechen\nQuadrat: Bewachen  Dreieck: Formation\nL1/R1: Strg/Alt  Options: Bestaetigen"},
    {"controller_nintendo",
     "Nintendo\nB: Select  A: Cancel\nY: Guard  X: Formation\nL/R: Ctrl/Alt  Plus: Confirm",
     "Nintendo\nB: Auswaehlen  A: Abbrechen\nY: Bewachen  X: Formation\nL/R: Strg/Alt  Plus: Bestaetigen"},
    {"controller_generic",
     "Controller\nA: Select  B: Cancel\nX: Guard  Y: Formation\nLB/RB: Ctrl/Alt  Menu: Confirm",
     "Controller\nA: Auswaehlen  B: Abbrechen\nX: Bewachen  Y: Formation\nLB/RB: Strg/Alt  Menue: Bestaetigen"},
    {"recovery_prompt", "Interrupted mission found. Continue?", "Unterbrochene Mission gefunden. Fortsetzen?"},
    {"continue", "Continue", "Fortsetzen"},
    {"main_menu", "Main Menu", "Hauptmenue"},
    {"missing_data_title", "Tiberian Dawn - Missing Game Data", "Tiberian Dawn - Spieldaten fehlen"},
    {"missing_data_message",
     "The required Command & Conquer data files are missing or incomplete.\n\nImport both original Gold CDs after restarting the app.",
     "Die erforderlichen Command-&-Conquer-Dateien fehlen oder sind unvollstaendig.\n\nImportiere nach dem Neustart beide originalen Gold-CDs."},

    {"import_guide_accessibility", "Guide for importing the original game data", "Anleitung zum Import der Original-Spieldaten"},
    {"import_title", "Import Original Game Data", "Original-Spieldaten importieren"},
    {"import_intro",
     "For legal reasons, Tiberian Dawn does not include the original game data. You need your own Command & Conquer Gold CDs. No files are uploaded.",
     "Tiberian Dawn enthält aus rechtlichen Gründen keine Originaldaten. Für das Spiel brauchst du deine eigenen Command & Conquer Gold-CDs. Es werden keine Dateien hochgeladen."},
    {"import_need_title", "You need", "Du benötigst"},
    {"import_requirements",
     "• CNC95_GDI.iso – the original GDI Gold CD\n• CNC95_Nod.iso – the original Nod Gold CD\n• at least 1.2 GB of free storage",
     "• CNC95_GDI.iso – die originale GDI Gold-CD\n• CNC95_Nod.iso – die originale Nod Gold-CD\n• mindestens 1,2 GB freien Speicher"},
    {"import_steps_title", "How it works", "So funktioniert es"},
    {"import_steps",
     "1. Put both ISO files in Files, iCloud Drive, or on a connected USB drive.\n\n2. Tap ‘Select Game Data’ below.\n\n3. Select GDI and Nod together and confirm with ‘Open’.\n\n4. Keep the app open while it verifies and installs the CDs.",
     "1. Lege beide ISO-Dateien in Dateien, iCloud Drive oder auf einem angeschlossenen USB-Laufwerk ab.\n\n2. Tippe unten auf „Spieldaten auswählen“.\n\n3. Markiere GDI und Nod gemeinsam und bestätige mit „Öffnen“.\n\n4. Lass die App geöffnet, während sie die CDs prüft und installiert."},
    {"import_alternative",
     "Alternatively, select exactly one prepared vanillatd folder. Ultimate Collection, The First Decade, and Remastered Collection are not supported.",
     "Alternativ kannst du genau einen bereits vorbereiteten vanillatd-Ordner auswählen. Ultimate Collection, The First Decade und Remastered Collection werden nicht unterstützt."},
    {"select_game_data", "Select Game Data", "Spieldaten auswählen"},
    {"select_game_data_hint", "Opens Files. Select the GDI and Nod ISO files together.", "Öffnet Dateien. Wähle dort die GDI- und die Nod-ISO gemeinsam aus."},
    {"use_transferred_cds", "Use Transferred GDI & Nod CDs", "Übertragene GDI- und Nod-CDs verwenden"},
    {"use_transferred_cds_hint", "Uses both ISO files already stored in this app without opening Files.", "Verwendet beide bereits in dieser App gespeicherten ISO-Dateien, ohne Dateien zu öffnen."},
    {"setup_later", "Set Up Later", "Später einrichten"},
    {"setup_later_hint", "Closes the app. This guide appears again at the next launch.", "Schließt die App. Beim nächsten Start erscheint diese Anleitung erneut."},
    {"picker_both_discs", "Select GDI and Nod Together", "GDI und Nod gemeinsam auswählen"},

    {"error_atomic_rollback", "Import failed; the previous data is safe in vanillatd.old", "Import fehlgeschlagen; die bisherigen Daten liegen sicher in vanillatd.old"},
    {"error_atomic_install", "Import could not be completed atomically; previous data was preserved", "Import konnte nicht atomar abgeschlossen werden; bisherige Daten wurden beibehalten"},
    {"error_storage_unknown", "Free storage could not be checked reliably", "Der freie Speicher konnte nicht zuverlässig geprüft werden"},
    {"error_storage_low", "At least 1.2 GB of free storage is required for a safe import", "Für den sicheren Import werden mindestens 1,2 GB freier Speicher benötigt"},
    {"error_write_install", "An installation file could not be written", "Installationsdatei konnte nicht geschrieben werden"},
    {"error_disc_identity", "A CD is neither GDI95 nor NOD95", "Eine CD ist weder GDI95 noch NOD95"},
    {"error_both_discs", "Select the GDI and Nod CDs together", "Bitte die GDI- und die Nod-CD gemeinsam auswählen"},
    {"error_save_file", "The file is empty, not a regular save, or larger than 128 MB", "Datei ist leer, kein regulärer Spielstand oder größer als 128 MB"},
    {"error_save_slots", "All 1000 save-game slots are occupied", "Alle 1000 Spielstandplätze sind belegt"},
    {"error_save_incompatible", "Not a compatible Tiberian Dawn save game", "Kein kompatibler Tiberian-Dawn-Spielstand"},
    {"error_save_sync", "The save game could not be synchronized safely", "Spielstand konnte nicht sicher synchronisiert werden"},
    {"error_save_atomic", "The save game could not be imported atomically", "Spielstand konnte nicht atomar übernommen werden"},
    {"error_migration_incomplete", "Migration is incomplete", "Die Migration ist unvollständig"},
    {"error_sources_incomplete", "The sources do not contain all required C&C Gold files", "Die Quellen enthalten nicht alle benötigten C&C-Gold-Dateien"},
    {"error_unknown_import", "Unknown import error", "Unbekannter Fehler beim Import"},

    {"save_invalid", "Invalid or outdated save game", "Ungültiger oder veralteter Spielstand"},
    {"save_excluded_format", "Will not be imported or exported · %@", "Wird nicht importiert oder exportiert · %@"},
    {"save_no_export", "There is no valid save game to export.", "Es gibt keinen gültigen Spielstand zum Exportieren."},
    {"save_manager_title", "Save Games & Files", "Spielstände & Dateien"},
    {"save_manager_explanation",
     "Import compatible .cncsave or original SAVEGAME files from Files, iCloud Drive, or USB. New files automatically use a free slot; existing saves are never overwritten.",
     "Importiere kompatible .cncsave- oder originale SAVEGAME-Dateien aus Dateien, iCloud Drive oder USB. Neue Dateien belegen automatisch einen freien Platz; vorhandene Spielstände werden niemals überschrieben."},
    {"import", "Import", "Importieren"},
    {"export", "Export", "Exportieren"},
    {"done", "Done", "Fertig"},
    {"save_none", "No valid manual save games yet. Recovery slots are intentionally hidden here.", "Noch keine gültigen manuellen Spielstände vorhanden. Recovery-Slots werden hier bewusst nicht angezeigt."},
    {"save_count_format", "%lu valid manual save game(s) · Recovery slots and settings are excluded.", "%lu gültige manuelle Spielstände · Recovery-Slots und Einstellungen sind ausgeschlossen."},
    {"ok", "OK", "OK"},
    {"save_picker_import", "Select Save Games", "Spielstände auswählen"},
    {"save_export_title", "Export Save Games", "Spielstände exportieren"},
    {"save_export_message", "Files can save to iCloud Drive, On My iPad, USB, or another provider.", "Die Dateien-App kann anschließend iCloud Drive, Auf meinem iPad, USB oder einen anderen Anbieter als Ziel verwenden."},
    {"selected", "Selected", "Ausgewählten"},
    {"all_valid", "All Valid", "Alle gültigen"},
    {"cancel", "Cancel", "Abbrechen"},
    {"export_unavailable", "Export Not Possible", "Export nicht möglich"},
    {"no_valid_saves", "No valid save games found.", "Keine gültigen Spielstände gefunden."},
    {"save_picker_export", "Save Games", "Spielstände sichern"},
    {"export_complete", "Export Complete", "Export abgeschlossen"},
    {"export_complete_message", "The selected save games were handed to Files.", "Die ausgewählten Spielstände wurden an die Dateien-App übergeben."},
    {"save_import_busy", "Save games are being verified and imported atomically …", "Spielstände werden geprüft und atomar importiert …"},
    {"save_import_count_format", "%lu save game(s) imported.", "%lu Spielstand/Spielstände wurden importiert."},
    {"save_not_imported_format", "\n\nNot imported:\n%@", "\n\nNicht übernommen:\n%@"},
    {"import_complete", "Import Complete", "Import abgeschlossen"},
    {"import_unavailable", "Import Not Possible", "Import nicht möglich"},

    {"import_progress_title", "Setting Up Game Data", "Spieldaten werden eingerichtet"},
    {"import_progress_note", "Keep the app open. ISO files are only read; they are not copied or uploaded.", "Bitte die App geöffnet lassen. Die ISO-Dateien werden nur gelesen und nicht kopiert oder hochgeladen."},
    {"import_help_format", "%@\n\nPlease check:\n• GDI and Nod Gold ISOs selected together\n• files fully available on iPad, iCloud Drive, or USB\n• at least 1.2 GB free storage\n\nOther C&C editions are not supported.", "%@\n\nPrüfe bitte:\n• GDI- und Nod-Gold-ISO gemeinsam ausgewählt\n• Dateien vollständig auf dem iPad, in iCloud Drive oder auf USB verfügbar\n• mindestens 1,2 GB freier Speicher\n\nAndere C&C-Ausgaben werden nicht unterstützt."},
    {"import_not_completed", "Import Not Completed", "Import nicht abgeschlossen"},
    {"later", "Later", "Später"},
    {"retry", "Try Again", "Erneut versuchen"},
    {"import_completed_message", "GDI and Nod data was verified and installed safely. Save games and settings remain separately accessible in Files.", "GDI- und Nod-Daten wurden geprüft und sicher installiert. Spielstände und Einstellungen bleiben getrennt in Dateien zugänglich."},
    {"start_game", "Start Game", "Spiel starten"},
    {"compact_warning", "Enlarge the window – the game area is too small here", "Fenster vergrößern – die Spielfläche ist hier zu klein"},
    {"migration_status", "Existing game data is being verified and moved to optimized storage.", "Vorhandene Spieldaten werden geprüft und in den optimierten Speicher verschoben."},
    {"import_sources_status", "The selected sources are being read, extracted, and fully verified.", "Die ausgewählten Quellen werden gelesen, extrahiert und vollständig geprüft."},
};
}

IPadLanguage Resolve_IPad_Language(int preference, const char* system_language_tag)
{
    if (preference == IPAD_LANGUAGE_GERMAN) return IPAD_EFFECTIVE_GERMAN;
    if (preference == IPAD_LANGUAGE_ENGLISH) return IPAD_EFFECTIVE_ENGLISH;

    if (system_language_tag && system_language_tag[0] && system_language_tag[1]
        && std::tolower(static_cast<unsigned char>(system_language_tag[0])) == 'd'
        && std::tolower(static_cast<unsigned char>(system_language_tag[1])) == 'e') {
        return IPAD_EFFECTIVE_GERMAN;
    }
    return IPAD_EFFECTIVE_ENGLISH;
}

const char* IPad_Localized_Text(IPadLanguage language, const char* key)
{
    if (!key) return "";
    for (const Translation& translation : Translations) {
        if (std::strcmp(translation.key, key) == 0) {
            return language == IPAD_EFFECTIVE_GERMAN ? translation.german : translation.english;
        }
    }
    return key;
}
