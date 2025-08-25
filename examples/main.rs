//! MIRA项目主示例 
//! My Intelligent Romantic Assistant - 展示如何使用多语言混合架构的记忆系统

use mira::{
    MemorySystem, MemoryConfig, MemoryType, EmotionalState,
    vector_store::{MockVectorStore, QdrantStore},
    bridge::{PythonInferenceClient, ZigSystemMonitor},
    emotion::{EmotionalEngine, PersonalityProfile, PersonalityGenerator},
};
use std::sync::Arc;
use tokio;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::init();
    
    println!("🎀 AI女友项目启动 - 多语言混合架构演示");
    println!("==================================================");
    
    // 1. 初始化核心系统
    println!("\n📦 初始化系统组件...");
    
    // 向量存储 (生产环境使用Qdrant，这里用Mock演示)
    let vector_store = Arc::new(MockVectorStore::new());
    
    // 内存系统配置
    let memory_config = MemoryConfig {
        short_term_limit: 50,
        long_term_threshold: 0.8,
        similarity_threshold: 0.7,
        cleanup_interval: 1800, // 30分钟
    };
    
    // 创建记忆系统
    let memory_system = MemorySystem::new(
        "demo_user".to_string(),
        vector_store,
        Some(memory_config),
    ).await?;
    
    // 启动后台清理任务
    let cleanup_handle = memory_system.start_background_cleanup();
    
    // 2. 初始化Python推理客户端
    println!("🐍 初始化Python推理层...");
    let python_client = PythonInferenceClient::new(
        "http://localhost:8000".to_string(),
        30,
    );
    
    // 检查Python服务状态
    if python_client.health_check().await {
        println!("✅ Python推理服务连接成功");
    } else {
        println!("⚠️  Python推理服务未运行，部分功能可能不可用");
    }
    
    // 3. 初始化Zig系统监控
    println!("⚡ 初始化Zig系统层...");
    let zig_monitor = ZigSystemMonitor::new(true, Some(1024 * 1024))?;
    let metrics = zig_monitor.get_performance_metrics();
    println!("💾 系统性能: 内存={}KB, CPU={:.1}%", 
        metrics.memory_usage / 1024, metrics.cpu_usage * 100.0);
    
    // 4. 初始化情感系统
    println!("💕 初始化情感系统...");
    let emotional_engine = EmotionalEngine::new();
    let personality_profile = PersonalityProfile::create_obedient_girlfriend();
    let personality_generator = PersonalityGenerator::new(personality_profile.clone());
    
    println!("👧 女友个性: {}", personality_profile.description);
    
    // 5. 演示记忆系统功能
    println!("\n🧠 演示记忆系统功能...");
    
    // 添加一些初始记忆
    let initial_memories = vec![
        ("我喜欢喝咖啡", vec!["咖啡", "喜欢"], 0.7, MemoryType::Preference),
        ("今天心情很好", vec!["心情", "开心"], 0.6, MemoryType::Emotional),
        ("用户的生日是12月25日", vec!["生日", "12月25日"], 0.9, MemoryType::LongTerm),
        ("刚才聊了关于工作的话题", vec!["工作", "聊天"], 0.4, MemoryType::ShortTerm),
    ];
    
    for (content, keywords, importance, memory_type) in initial_memories {
        let memory_id = memory_system.add_memory(
            memory_type,
            content.to_string(),
            keywords.iter().map(|s| s.to_string()).collect(),
            importance,
            None,
        ).await?;
        
        println!("✅ 添加记忆: {} (ID: {})", content, memory_id);
    }
    
    // 6. 演示情感系统
    println!("\n💝 演示情感系统...");
    
    let user_inputs = vec![
        "你真聪明！我很喜欢你",
        "今天工作好累啊",
        "你的声音很好听",
        "我想你了",
    ];
    
    let mut current_emotion = EmotionalState::default();
    
    for user_input in user_inputs {
        println!("\n👤 用户: {}", user_input);
        
        // 分析情感触发器
        let memories = memory_system.retrieve_memories(
            user_input,
            None,
            Some(3),
        ).await?;
        
        let triggers = emotional_engine.analyze_interaction(user_input, &memories);
        
        // 处理情感变化
        for (trigger, intensity) in triggers {
            current_emotion = emotional_engine.process_trigger(
                &current_emotion,
                trigger,
                intensity,
            );
            println!("💫 情感触发: {:?} (强度: {:.2})", trigger, intensity);
        }
        
        // 更新记忆系统的情感状态
        memory_system.update_emotional_state(current_emotion.clone()).await;
        
        // 生成个性化回复
        let base_response = format!("收到你的消息了！"); // 实际中会调用Python推理
        let emotional_response = emotional_engine.generate_emotional_expression(
            &current_emotion,
            &base_response,
        );
        let final_response = personality_generator.generate_personalized_response(
            &emotional_response,
            user_input,
        );
        
        println!("🤖 AI女友: {}", final_response);
        println!("😊 当前情感: 开心={:.2}, 亲密={:.2}, 信任={:.2}, 心情={}",
            current_emotion.happiness,
            current_emotion.affection,
            current_emotion.trust,
            current_emotion.mood,
        );
        
        // 添加互动记忆
        memory_system.add_memory(
            MemoryType::ShortTerm,
            format!("用户说: {} | 我回复: {}", user_input, final_response),
            vec!["对话", "互动"].iter().map(|s| s.to_string()).collect(),
            0.5,
            Some(current_emotion.clone()),
        ).await?;
    }
    
    // 7. 演示记忆检索
    println!("\n🔍 演示智能记忆检索...");
    
    let query_tests = vec![
        "用户喜欢什么",
        "关于生日的信息",
        "最近的对话",
        "情感相关的记忆",
    ];
    
    for query in query_tests {
        println!("\n🔎 查询: {}", query);
        let results = memory_system.retrieve_memories(
            query,
            None,
            Some(3),
        ).await?;
        
        for (i, memory) in results.iter().enumerate() {
            println!("  {}. {} (重要性: {:.2}, 类型: {:?})",
                i + 1, memory.content, memory.importance, memory.memory_type);
        }
    }
    
    // 8. 显示系统统计
    println!("\n📊 系统统计信息...");
    let memory_stats = memory_system.get_memory_stats().await;
    let final_metrics = zig_monitor.get_performance_metrics();
    
    println!("📈 记忆统计:");
    for (type_name, count) in memory_stats {
        println!("  {}: {} 条", type_name, count);
    }
    
    println!("📈 性能指标:");
    println!("  内存使用: {}KB", final_metrics.memory_usage / 1024);
    println!("  CPU使用: {:.1}%", final_metrics.cpu_usage * 100.0);
    if let Some(pool_size) = final_metrics.pool_size {
        println!("  内存池大小: {}KB", pool_size / 1024);
    }
    
    // 9. 主动互动演示
    println!("\n💬 演示主动互动...");
    if let Some(initiative_msg) = personality_generator.generate_initiative_message("用户上次说工作很累") {
        println!("🤖 主动关心: {}", initiative_msg);
    }
    
    println!("\n🎉 演示完成！");
    println!("==================================================");
    println!("这个演示展示了AI女友项目的核心能力：");
    println!("✨ 智能记忆管理 (Rust + 向量数据库)");
    println!("🧠 AI推理和对话 (Python + 大语言模型)");  
    println!("⚡ 高性能系统层 (Zig + 内存池)");
    println!("💕 情感建模和个性化 (混合架构)");
    println!("🔄 实时情感状态管理");
    println!("📚 上下文感知的记忆检索");
    
    // 保持服务运行一段时间观察后台任务
    println!("\n⏰ 保持运行30秒观察后台清理任务...");
    tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;
    
    // 停止后台任务
    cleanup_handle.abort();
    
    Ok(())
}

/// 如果Python服务未运行，提供模拟的推理结果
async fn mock_inference_demo() {
    println!("🎭 模拟推理演示 (Python服务未运行)");
    
    // 模拟嵌入生成
    let mock_embedding: Vec<f32> = (0..768).map(|i| (i as f32) * 0.001).collect();
    println!("📊 模拟生成了{}维嵌入向量", mock_embedding.len());
    
    // 模拟情感分析
    let mock_emotion = EmotionalState {
        happiness: 0.7,
        affection: 0.6,
        trust: 0.5,
        dependency: 0.4,
        mood: "开心".to_string(),
        timestamp: chrono::Utc::now(),
    };
    println!("💝 模拟情感分析: 开心={:.1}, 亲密={:.1}", 
        mock_emotion.happiness, mock_emotion.affection);
}
