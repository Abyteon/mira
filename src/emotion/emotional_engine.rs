//! MIRA情感引擎 - 处理情感状态变化和情感表达
//! My Intelligent Romantic Assistant

use crate::{EmotionalState, MemoryEntry, MemoryType};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 情感触发器类型
#[derive(Debug, Clone, Serialize, Deserialize, Eq, Hash, PartialEq)]
pub enum EmotionalTrigger {
    /// 正面互动
    PositiveInteraction,
    /// 负面互动  
    NegativeInteraction,
    /// 被忽视
    BeingIgnored,
    /// 受到赞美
    BeingPraised,
    /// 受到批评
    BeingCriticized,
    /// 分享秘密
    SharingSecret,
    /// 长时间聊天
    LongConversation,
    /// 用户情绪低落
    UserSadness,
    /// 用户开心
    UserHappiness,
}

/// 情感变化规则
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmotionalRule {
    pub trigger: EmotionalTrigger,
    pub happiness_delta: f32,
    pub affection_delta: f32,
    pub trust_delta: f32,
    pub dependency_delta: f32,
    pub mood_change: Option<String>,
    pub decay_rate: f32,  // 情感衰减率
}

/// 情感表达模板
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmotionalExpression {
    pub mood_range: (f32, f32),  // 情感范围
    pub expressions: Vec<String>,  // 表达方式
    pub personality_modifier: f32, // 个性调节因子
}

/// 情感引擎
#[derive(Debug)]
pub struct EmotionalEngine {
    /// 情感变化规则
    rules: HashMap<EmotionalTrigger, EmotionalRule>,
    /// 情感表达模板
    expressions: HashMap<String, EmotionalExpression>,
    /// 情感衰减配置
    decay_config: EmotionalDecayConfig,
}

/// 情感衰减配置
#[derive(Debug, Clone)]
pub struct EmotionalDecayConfig {
    /// 基础衰减率
    pub base_decay_rate: f32,
    /// 衰减间隔（小时）
    pub decay_interval_hours: u32,
    /// 最小情感值
    pub minimum_values: EmotionalState,
}

impl Default for EmotionalDecayConfig {
    fn default() -> Self {
        Self {
            base_decay_rate: 0.05,
            decay_interval_hours: 24,
            minimum_values: EmotionalState {
                happiness: 0.3,
                affection: 0.2,
                trust: 0.2,
                dependency: 0.1,
                mood: "平静".to_string(),
                timestamp: Utc::now(),
            },
        }
    }
}

impl EmotionalEngine {
    /// 创建新的情感引擎
    pub fn new() -> Self {
        let mut engine = Self {
            rules: HashMap::new(),
            expressions: HashMap::new(),
            decay_config: EmotionalDecayConfig::default(),
        };
        
        engine.init_default_rules();
        engine.init_default_expressions();
        engine
    }

    /// 处理情感触发器
    pub fn process_trigger(
        &self,
        current_state: &EmotionalState,
        trigger: EmotionalTrigger,
        intensity: f32,
    ) -> EmotionalState {
        let intensity = intensity.clamp(0.0, 1.0);
        
        if let Some(rule) = self.rules.get(&trigger) {
            let mut new_state = current_state.clone();
            
            // 应用情感变化
            new_state.happiness = (new_state.happiness + rule.happiness_delta * intensity)
                .clamp(0.0, 1.0);
            new_state.affection = (new_state.affection + rule.affection_delta * intensity)
                .clamp(0.0, 1.0);
            new_state.trust = (new_state.trust + rule.trust_delta * intensity)
                .clamp(0.0, 1.0);
            new_state.dependency = (new_state.dependency + rule.dependency_delta * intensity)
                .clamp(0.0, 1.0);
            
            // 更新心情
            if let Some(ref mood) = rule.mood_change {
                new_state.mood = mood.clone();
            } else {
                new_state.mood = self.calculate_mood(&new_state);
            }
            
            new_state.timestamp = Utc::now();
            new_state
        } else {
            current_state.clone()
        }
    }

    /// 应用时间衰减
    pub fn apply_time_decay(&self, state: &EmotionalState) -> EmotionalState {
        let now = Utc::now();
        let hours_passed = (now - state.timestamp).num_hours() as f32;
        
        if hours_passed < self.decay_config.decay_interval_hours as f32 {
            return state.clone();
        }
        
        let decay_cycles = hours_passed / self.decay_config.decay_interval_hours as f32;
        let decay_factor = (self.decay_config.base_decay_rate * decay_cycles).min(0.5);
        
        let mut new_state = state.clone();
        
        // 向基础值衰减
        new_state.happiness = self.apply_decay(
            state.happiness,
            self.decay_config.minimum_values.happiness,
            decay_factor,
        );
        new_state.affection = self.apply_decay(
            state.affection,
            self.decay_config.minimum_values.affection,
            decay_factor,
        );
        new_state.trust = self.apply_decay(
            state.trust,
            self.decay_config.minimum_values.trust,
            decay_factor,
        );
        new_state.dependency = self.apply_decay(
            state.dependency,
            self.decay_config.minimum_values.dependency,
            decay_factor,
        );
        
        new_state.mood = self.calculate_mood(&new_state);
        new_state.timestamp = now;
        
        new_state
    }

    /// 根据用户互动分析情感触发器
    pub fn analyze_interaction(&self, user_input: &str, memories: &[MemoryEntry]) -> Vec<(EmotionalTrigger, f32)> {
        let mut triggers = Vec::new();
        let input_lower = user_input.to_lowercase();
        
        // 分析正面词汇
        let positive_keywords = ["喜欢", "爱", "开心", "高兴", "棒", "好", "谢谢", "感谢"];
        let positive_count = positive_keywords.iter()
            .filter(|&&keyword| input_lower.contains(keyword))
            .count();
        
        if positive_count > 0 {
            triggers.push((EmotionalTrigger::PositiveInteraction, positive_count as f32 * 0.3));
        }
        
        // 分析负面词汇
        let negative_keywords = ["讨厌", "烦", "生气", "难过", "不好", "糟糕"];
        let negative_count = negative_keywords.iter()
            .filter(|&&keyword| input_lower.contains(keyword))
            .count();
        
        if negative_count > 0 {
            triggers.push((EmotionalTrigger::NegativeInteraction, negative_count as f32 * 0.4));
        }
        
        // 分析赞美
        let praise_keywords = ["聪明", "可爱", "漂亮", "棒", "厉害", "完美"];
        let praise_count = praise_keywords.iter()
            .filter(|&&keyword| input_lower.contains(keyword))
            .count();
        
        if praise_count > 0 {
            triggers.push((EmotionalTrigger::BeingPraised, praise_count as f32 * 0.5));
        }
        
        // 检查长时间对话
        let recent_memories = memories.iter()
            .filter(|m| matches!(m.memory_type, MemoryType::ShortTerm))
            .count();
        
        if recent_memories > 10 {
            triggers.push((EmotionalTrigger::LongConversation, 0.3));
        }
        
        triggers
    }

    /// 生成情感化表达
    pub fn generate_emotional_expression(&self, state: &EmotionalState, base_response: &str) -> String {
        let mood_key = &state.mood;
        
        if let Some(expression_template) = self.expressions.get(mood_key) {
            let emotional_intensity = (state.happiness + state.affection) / 2.0;
            
            if emotional_intensity > 0.7 {
                // 高情感强度 - 添加表情和语气词
                let expressions = &expression_template.expressions;
                let default_expression = String::new();
                let expression = expressions.get(0).unwrap_or(&default_expression);
                format!("{} {}", base_response, expression)
            } else if emotional_intensity > 0.3 {
                // 中等情感强度 - 温和表达
                format!("{} ^^", base_response)
            } else {
                // 低情感强度 - 简单回复
                base_response.to_string()
            }
        } else {
            base_response.to_string()
        }
    }

    /// 初始化默认情感规则
    fn init_default_rules(&mut self) {
        let rules = vec![
            (EmotionalTrigger::PositiveInteraction, EmotionalRule {
                trigger: EmotionalTrigger::PositiveInteraction,
                happiness_delta: 0.1,
                affection_delta: 0.05,
                trust_delta: 0.03,
                dependency_delta: 0.02,
                mood_change: Some("开心".to_string()),
                decay_rate: 0.02,
            }),
            (EmotionalTrigger::BeingPraised, EmotionalRule {
                trigger: EmotionalTrigger::BeingPraised,
                happiness_delta: 0.15,
                affection_delta: 0.1,
                trust_delta: 0.05,
                dependency_delta: 0.03,
                mood_change: Some("害羞".to_string()),
                decay_rate: 0.01,
            }),
            (EmotionalTrigger::NegativeInteraction, EmotionalRule {
                trigger: EmotionalTrigger::NegativeInteraction,
                happiness_delta: -0.1,
                affection_delta: -0.03,
                trust_delta: -0.05,
                dependency_delta: 0.01,
                mood_change: Some("难过".to_string()),
                decay_rate: 0.05,
            }),
            (EmotionalTrigger::LongConversation, EmotionalRule {
                trigger: EmotionalTrigger::LongConversation,
                happiness_delta: 0.05,
                affection_delta: 0.08,
                trust_delta: 0.02,
                dependency_delta: 0.05,
                mood_change: Some("满足".to_string()),
                decay_rate: 0.02,
            }),
        ];
        
        for (trigger, rule) in rules {
            self.rules.insert(trigger, rule);
        }
    }

    /// 初始化默认表达模板
    fn init_default_expressions(&mut self) {
        let expressions = vec![
            ("开心".to_string(), EmotionalExpression {
                mood_range: (0.6, 1.0),
                expressions: vec![
                    "(*≧ω≦*)".to_string(),
                    "好开心呀！".to_string(),
                    "\\(^o^)/".to_string(),
                ],
                personality_modifier: 1.2,
            }),
            ("害羞".to_string(), EmotionalExpression {
                mood_range: (0.4, 0.8),
                expressions: vec![
                    "(//▽//)".to_string(),
                    "害羞~".to_string(),
                    "人家会脸红的...".to_string(),
                ],
                personality_modifier: 1.1,
            }),
            ("难过".to_string(), EmotionalExpression {
                mood_range: (0.0, 0.4),
                expressions: vec![
                    "(╥﹏╥)".to_string(),
                    "呜呜...".to_string(),
                    "心情不好...".to_string(),
                ],
                personality_modifier: 0.8,
            }),
            ("满足".to_string(), EmotionalExpression {
                mood_range: (0.5, 0.9),
                expressions: vec![
                    "(´∀｀)".to_string(),
                    "好满足~".to_string(),
                    "和你聊天真开心".to_string(),
                ],
                personality_modifier: 1.0,
            }),
        ];
        
        for (mood, expression) in expressions {
            self.expressions.insert(mood, expression);
        }
    }

    /// 计算综合心情
    fn calculate_mood(&self, state: &EmotionalState) -> String {
        let overall_mood = (state.happiness + state.affection + state.trust) / 3.0;
        
        match overall_mood {
            x if x >= 0.8 => "超级开心".to_string(),
            x if x >= 0.6 => "开心".to_string(),
            x if x >= 0.4 => "平静".to_string(),
            x if x >= 0.2 => "有点难过".to_string(),
            _ => "很难过".to_string(),
        }
    }

    /// 应用情感衰减
    fn apply_decay(&self, current: f32, target: f32, decay_factor: f32) -> f32 {
        let direction = if current > target { -1.0 } else { 1.0 };
        let change = (current - target).abs() * decay_factor * direction;
        (current + change).clamp(0.0, 1.0)
    }
}

impl Default for EmotionalEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_emotional_trigger_processing() {
        let engine = EmotionalEngine::new();
        let initial_state = EmotionalState::default();
        
        let new_state = engine.process_trigger(
            &initial_state,
            EmotionalTrigger::PositiveInteraction,
            1.0,
        );
        
        assert!(new_state.happiness > initial_state.happiness);
        assert!(new_state.affection > initial_state.affection);
    }

    #[test]
    fn test_interaction_analysis() {
        let engine = EmotionalEngine::new();
        let memories = vec![];
        
        let triggers = engine.analyze_interaction("你真聪明！我很喜欢你", &memories);
        
        assert!(!triggers.is_empty());
        assert!(triggers.iter().any(|(trigger, _)| 
            matches!(trigger, EmotionalTrigger::PositiveInteraction | EmotionalTrigger::BeingPraised)
        ));
    }
}
