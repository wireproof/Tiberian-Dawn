#pragma once
#ifdef __cplusplus
extern "C" {
#endif
void WP_InitRules(void);
void WP_TickCheats(void);
void WP_ResetLiveCheats(void);
int WP_InstantBuild(const void* house);
int WP_ZeroCost(const void* house);
int WP_PlayerInvincible(const void* house);
int WP_ScalePlayerSpeed(const void* house,int base,int category);
int WP_RuleCount(void);
const char* WP_RuleName(int index);
const char* WP_RuleKey(int index);
int WP_RuleDefault(int index);
int WP_RuleMin(int index);
int WP_RuleMax(int index);
int WP_RulesActive(void);
const char* WP_RuleHelp(int index);
int WP_RuleChoiceCount(int index);
int WP_RuleChoiceValue(int index, int choice);
const char* WP_RuleChoiceLabel(int index, int choice);
int WP_RuleValueValid(int index, int value);
int WP_LoadRule(const char* key, int fallback, int low, int high);
void WP_ShowWorkshop(void);
#ifdef __cplusplus
}
#endif
