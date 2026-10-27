# 0.7.2 production and rendering update

2026-10-27 · build 702 · prerelease

Hold a unit production icon for half a second (right-click on Mac) to cancel that type's waiting entries and unfinished active unit. Credits already spent on the unfinished unit are refunded by the factory. Unstarted queue entries cost nothing; completed units are retained. Other queued unit types continue afterward. Dispatch waits for cancellation acknowledgement, including when a production command is already in flight.

Infantry rally orders now wait until the barracks/Hand of Nod exit movement and queued mission transition finish. This avoids the exit's Guard transition discarding the rally destination. Vehicle rally behavior is retained.

Remastered ground tiles draw before decals so adjacent tiles cannot cut larger scorch marks into rectangles. Image and GPU texture caches retain hot entries rather than clearing all textures together; decoded atlas images have bounded cache costs. The top bar's black gap is covered by Collection panel artwork. The sidebar remains the existing adapted layout; this release does not claim a complete recreation of the Collection's command-bar layout.

Validation: 27 host tests including cancellation of waiting entries while a head is dispatched; iOS compilation and signing; Universal 2 Mac packaging; isolated Mac gameplay verified two new infantry reaching a barracks rally point and cancellation clearing a paid queue. In the paid test one 240-credit soldier completed before cancellation and the final balance was 1760 from 2000, preserving the completed unit and refunding unfinished production. Physical touch behavior and performance improvement need device confirmation. The user's cheat-induced airstrike issue is outside this change.

Public packages exclude extracted Collection artwork, game data, provisioning profiles and private signed IPAs. See REMASTERED-0.7.1.md for local asset import and source/submodule instructions. Previous gameplay recordings remain on the 0.7.1 release and depict that earlier preview.
