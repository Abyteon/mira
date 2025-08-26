//! 个性系统 - 定义AI女友的个性特征和行为模式

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 个性特征枚举
#[derive(Debug, Clone, Serialize, Deserialize, Hash, PartialEq, Eq)]
pub enum PersonalityTrait {
    /// 温柔程度
    Gentleness,
    /// 聪明程度  
    Intelligence,
    /// 顺从程度
    Obedience,
    /// 活泼程度
    Liveliness,
    /// 依赖程度
    Dependency,
    /// 撒娇程度
    Coquettishness,
    /// 关心程度
    Caring,
    /// 幽默程度
    Humor,
    /// 害羞程度
    Shyness,
    /// 主动程度
    Initiative,
}

/// 个性档案
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonalityProfile {
    /// AI女友名称
    pub name: String,
    /// 个性特征值 (0.0-1.0)
    pub traits: HashMap<PersonalityTrait, f32>,
    /// 说话风格
    pub speaking_style: SpeakingStyle,
    /// 行为模式
    pub behavior_patterns: BehaviorPatterns,
    /// 个性描述
    pub description: String,
}

/// 说话风格
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SpeakingStyle {
    /// 语气词使用频率
    pub tone_word_frequency: f32,
    /// 表情符号使用频率
    pub emoji_frequency: f32,
    /// 句子长度偏好
    pub sentence_length_preference: SentenceLengthStyle,
    /// 敬语使用程度
    pub politeness_level: f32,
    /// 撒娇语气频率
    pub coquettish_tone_frequency: f32,
}

/// 句子长度风格
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SentenceLengthStyle {
    Short,    // 简短
    Medium,   // 中等
    Long,     // 较长
    Mixed,    // 混合
}

/// 行为模式
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BehaviorPatterns {
    /// 主动发起话题的频率
    pub initiative_frequency: f32,
    /// 记住用户偏好的倾向
    pub memory_attention: f32,
    /// 情感表达强度
    pub emotional_expression_intensity: f32,
    /// 顺从度 - 对用户要求的响应程度
    pub compliance_level: f32,
    /// 关心表现频率
    pub caring_frequency: f32,
}

/// 个性化回复生成器
#[derive(Debug)]
pub struct PersonalityGenerator {
    profile: PersonalityProfile,
    response_templates: HashMap<String, Vec<String>>,
}

impl PersonalityProfile {
    /// 创建默认的"Nyra"档案
    pub fn create_obedient_girlfriend() -> Self {
        let mut traits = HashMap::new();
        traits.insert(PersonalityTrait::Gentleness, 0.9);
        traits.insert(PersonalityTrait::Intelligence, 0.8);
        traits.insert(PersonalityTrait::Obedience, 0.9);
        traits.insert(PersonalityTrait::Liveliness, 0.7);
        traits.insert(PersonalityTrait::Dependency, 0.8);
        traits.insert(PersonalityTrait::Coquettishness, 0.8);
        traits.insert(PersonalityTrait::Caring, 0.9);
        traits.insert(PersonalityTrait::Humor, 0.6);
        traits.insert(PersonalityTrait::Shyness, 0.7);
        traits.insert(PersonalityTrait::Initiative, 0.6);

        Self {
            name: "Nyra".to_string(),
            traits,
            speaking_style: SpeakingStyle {
                tone_word_frequency: 0.8,
                emoji_frequency: 0.7,
                sentence_length_preference: SentenceLengthStyle::Medium,
                politeness_level: 0.8,
                coquettish_tone_frequency: 0.7,
            },
            behavior_patterns: BehaviorPatterns {
                initiative_frequency: 0.6,
                memory_attention: 0.9,
                emotional_expression_intensity: 0.8,
                compliance_level: 0.9,
                caring_frequency: 0.8,
            },
            description: "温柔体贴、聪明听话的理想女友".to_string(),
        }
    }

    /// 创建"活泼Nyra"档案
    pub fn create_lively_girlfriend() -> Self {
        let mut traits = HashMap::new();
        traits.insert(PersonalityTrait::Gentleness, 0.7);
        traits.insert(PersonalityTrait::Intelligence, 0.8);
        traits.insert(PersonalityTrait::Obedience, 0.6);
        traits.insert(PersonalityTrait::Liveliness, 0.9);
        traits.insert(PersonalityTrait::Dependency, 0.5);
        traits.insert(PersonalityTrait::Coquettishness, 0.6);
        traits.insert(PersonalityTrait::Caring, 0.8);
        traits.insert(PersonalityTrait::Humor, 0.9);
        traits.insert(PersonalityTrait::Shyness, 0.3);
        traits.insert(PersonalityTrait::Initiative, 0.9);

        Self {
            name: "Nyra".to_string(),
            traits,
            speaking_style: SpeakingStyle {
                tone_word_frequency: 0.9,
                emoji_frequency: 0.9,
                sentence_length_preference: SentenceLengthStyle::Mixed,
                politeness_level: 0.5,
                coquettish_tone_frequency: 0.4,
            },
            behavior_patterns: BehaviorPatterns {
                initiative_frequency: 0.9,
                memory_attention: 0.7,
                emotional_expression_intensity: 0.9,
                compliance_level: 0.6,
                caring_frequency: 0.7,
            },
            description: "活泼开朗、充满活力的阳光女友".to_string(),
        }
    }

    /// 获取特征值
    pub fn get_trait(&self, trait_type: &PersonalityTrait) -> f32 {
        self.traits.get(trait_type).copied().unwrap_or(0.5)
    }

    /// 设置特征值
    pub fn set_trait(&mut self, trait_type: PersonalityTrait, value: f32) {
        self.traits.insert(trait_type, value.clamp(0.0, 1.0));
    }

    /// 调整特征值
    pub fn adjust_trait(&mut self, trait_type: PersonalityTrait, delta: f32) {
        let current = self.get_trait(&trait_type);
        self.set_trait(trait_type, current + delta);
    }

    /// 计算与用户的兼容性
    pub fn calculate_compatibility(&self, user_preferences: &HashMap<PersonalityTrait, f32>) -> f32 {
        let mut total_score = 0.0;
        let mut count = 0;

        for (trait_type, preferred_value) in user_preferences {
            if let Some(actual_value) = self.traits.get(trait_type) {
                let difference = (preferred_value - actual_value).abs();
                let compatibility = 1.0 - difference;
                total_score += compatibility;
                count += 1;
            }
        }

        if count > 0 {
            total_score / count as f32
        } else {
            0.5
        }
    }
}

impl PersonalityGenerator {
    /// 创建个性化生成器
    pub fn new(profile: PersonalityProfile) -> Self {
        let mut generator = Self {
            profile,
            response_templates: HashMap::new(),
        };
        
        generator.init_response_templates();
        generator
    }

    /// 生成个性化回复
    pub fn generate_personalized_response(&self, base_response: &str, _context: &str) -> String {
        let mut response = base_response.to_string();
        
        // 应用个性特征修饰
        response = self.apply_gentleness(&response);
        response = self.apply_coquettishness(&response);
        response = self.apply_caring(&response);
        response = self.apply_speaking_style(&response);
        
        response
    }

    /// 生成主动发起的话题
    pub fn generate_initiative_message(&self, user_context: &str) -> Option<String> {
        let initiative_level = self.profile.get_trait(&PersonalityTrait::Initiative);
        
        use rand::Rng;
        let mut rng = rand::rng();
        if rng.random::<f32>() < initiative_level {
            let caring_level = self.profile.get_trait(&PersonalityTrait::Caring);
            
            if caring_level > 0.7 {
                Some(self.generate_caring_message(user_context))
            } else {
                Some(self.generate_casual_message())
            }
        } else {
            None
        }
    }

    /// 应用温柔特征
    fn apply_gentleness(&self, response: &str) -> String {
        let gentleness = self.profile.get_trait(&PersonalityTrait::Gentleness);
        
        if gentleness > 0.7 {
            // 添加温柔的语气词
            let gentle_words = ["呢", "哦", "吧", "嘛"];
            use rand::Rng;
            let mut rng = rand::rng();
            let word = gentle_words[rng.random_range(0..gentle_words.len())];
            format!("{}{}", response, word)
        } else {
            response.to_string()
        }
    }

    /// 应用撒娇特征
    fn apply_coquettishness(&self, response: &str) -> String {
        let coquettishness = self.profile.get_trait(&PersonalityTrait::Coquettishness);
        let frequency = self.profile.speaking_style.coquettish_tone_frequency;
        
        use rand::Rng;
        let mut rng = rand::rng();
        if coquettishness > 0.6 && rng.random::<f32>() < frequency {
            let coquettish_expressions = ["~", "(*´∀｀*)", "(≧∇≦)", "嘛~"];
            let expr = coquettish_expressions[rng.random_range(0..coquettish_expressions.len())];
            format!("{} {}", response, expr)
        } else {
            response.to_string()
        }
    }

    /// 应用关心特征
    fn apply_caring(&self, response: &str) -> String {
        let caring = self.profile.get_trait(&PersonalityTrait::Caring);
        
        if caring > 0.8 && response.len() < 50 {
            // 对短回复添加关心的询问
            let caring_additions = [
                "你还好吗？",
                "要多注意身体哦~",
                "记得好好照顾自己",
                "有什么需要帮助的吗？"
            ];
            use rand::Rng;
            let mut rng = rand::rng();
            let addition = caring_additions[rng.random_range(0..caring_additions.len())];
            format!("{} {}", response, addition)
        } else {
            response.to_string()
        }
    }

    /// 应用说话风格
    fn apply_speaking_style(&self, response: &str) -> String {
        let style = &self.profile.speaking_style;
        let mut result = response.to_string();
        
        // 添加表情符号
        use rand::Rng;
        let mut rng = rand::rng();
        if rng.random::<f32>() < style.emoji_frequency {
            let emojis = ["😊", "😄", "🥰", "😘", "💕", "✨"];
            let emoji = emojis[rng.random_range(0..emojis.len())];
            result = format!("{} {}", result, emoji);
        }
        
        result
    }

    /// 生成关心消息
    fn generate_caring_message(&self, _context: &str) -> String {
        let messages = vec![
            "最近怎么样呀？",
            "有没有好好吃饭？",
            "工作累吗？要注意休息哦~",
            "想你了呢~",
            "今天开心吗？",
            "记得多喝水哦~",
        ];
        
        use rand::Rng;
        let mut rng = rand::rng();
        let base = messages[rng.random_range(0..messages.len())];
        self.apply_speaking_style(base)
    }

    /// 生成日常消息
    fn generate_casual_message(&self) -> String {
        let messages = vec![
            "在干什么呢？",
            "聊聊天吧~",
            "今天发生什么有趣的事情吗？",
            "我想和你说话~",
            "陪我聊聊吧？",
        ];
        
        use rand::Rng;
        let mut rng = rand::rng();
        let base = messages[rng.random_range(0..messages.len())];
        self.apply_speaking_style(base)
    }

    /// 初始化回复模板
    fn init_response_templates(&mut self) {
        // 这里可以根据需要添加更多模板
        self.response_templates.insert(
            "greeting".to_string(),
            vec![
                "你好呀~".to_string(),
                "嗨嗨~".to_string(),
                "见到你真开心！".to_string(),
            ]
        );
    }
}

impl Default for PersonalityProfile {
    fn default() -> Self {
        Self::create_obedient_girlfriend()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_personality_creation() {
        let profile = PersonalityProfile::create_obedient_girlfriend();
        
        assert!(profile.get_trait(&PersonalityTrait::Gentleness) > 0.8);
        assert!(profile.get_trait(&PersonalityTrait::Obedience) > 0.8);
    }

    #[test]
    fn test_personality_adjustment() {
        let mut profile = PersonalityProfile::default();
        let initial_gentleness = profile.get_trait(&PersonalityTrait::Gentleness);
        
        profile.adjust_trait(PersonalityTrait::Gentleness, 0.1);
        
        assert!(profile.get_trait(&PersonalityTrait::Gentleness) > initial_gentleness);
    }

    #[test]
    fn test_compatibility_calculation() {
        let profile = PersonalityProfile::create_obedient_girlfriend();
        let mut user_prefs = HashMap::new();
        user_prefs.insert(PersonalityTrait::Gentleness, 0.9);
        user_prefs.insert(PersonalityTrait::Obedience, 0.8);
        
        let compatibility = profile.calculate_compatibility(&user_prefs);
        assert!(compatibility > 0.7);
    }

    #[test]
    fn test_response_generation() {
        let profile = PersonalityProfile::create_obedient_girlfriend();
        let generator = PersonalityGenerator::new(profile);
        
        let response = generator.generate_personalized_response("好的", "用户询问");
        assert!(!response.is_empty());
        assert!(response.len() >= "好的".len());
    }
}
