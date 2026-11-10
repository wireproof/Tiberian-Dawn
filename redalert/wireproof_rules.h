#pragma once
#ifdef __cplusplus
extern "C" {
#endif
void RA_InitRules(void);
void RA_RestoreRules(void);
void RA_ApplyRules(void);
int RA_RulesActive(void);
int RA_RulesRequireSinglePlayer(void);
int RA_RuleCount(void);
const char* RA_RuleName(int index);
const char* RA_RuleKey(int index);
int RA_RuleDefault(int index);
int RA_RuleMin(int index);
int RA_RuleMax(int index);
int RA_RuleChoiceCount(int index);
int RA_RuleChoiceValue(int index,int choice);
const char* RA_RuleChoiceLabel(int index,int choice);
int RA_RuleValueValid(int index,int value);
int RA_LoadRule(const char* key,int fallback,int low,int high);
void RA_ShowWorkshop(void);
void RA_ShowMultiplayerRestriction(void);
#ifdef __cplusplus
}
#endif
