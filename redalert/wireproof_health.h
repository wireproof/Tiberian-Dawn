#pragma once
// Extra native health bars must never expand intelligence or multiplayer UI.
namespace RAHealth {
inline bool ShowDamagedBuilding(bool available, bool enabled, bool singlePlayer,
                                bool owned, bool visible, bool building,
                                int strength, int maximum)
{
    return available && enabled && singlePlayer && owned && visible && building
        && strength > 0 && strength < maximum;
}
}
