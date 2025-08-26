//! MIRA交互式演示 - 真实对话体验
//! My Intelligent Romantic Assistant - 与AI女友实时聊天

use mira::{
    MemorySystem, MemoryConfig, MemoryType, EmotionalState,
    vector_store::MockVectorStore,
    bridge::{PythonInferenceClient, ZigSystemMonitor},
    emotion::{EmotionalEngine, PersonalityProfile, PersonalityGenerator},
};
use std::sync::Arc;
use std::io::{self, Write};
use tokio;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::fmt::init();
    
    println!("💕 欢迎来到MIRA AI女友交互系统 💕");
    println!("==================================================");
    println!("🎯 输入 'quit' 或 'exit' 退出");
    println!("🎯 输入 'help' 查看更多命令");
    println!("🎯 输入 'status' 查看系统状态");
    println!("==================================================\n");
    
    // 初始化系统组件
    println!("📦 正在初始化系统...");
    
    let vector_store = Arc::new(MockVectorStore::new());
    let memory_config = MemoryConfig {
        short_term_limit: 50,
        long_term_threshold: 0.8,
        similarity_threshold: 0.8,
        cleanup_interval: 3600, // 1小时，以秒为单位
    };
    
    let mut memory_system = MemorySystem::new(
        "interactive_user".to_string(),
        vector_store,
        Some(memory_config.clone()),
    ).await?;
    
    // 初始化Python推理客户端
    let python_client = PythonInferenceClient::new("http://localhost:8000".to_string(), 30);
    let _zig_monitor = ZigSystemMonitor::new(true, Some(1024*1024)).expect("Zig监控初始化失败");
    
    // 初始化情感和个性系统
    let emotional_engine = EmotionalEngine::new();
    let personality = PersonalityProfile::create_obedient_girlfriend();
    let personality_generator = PersonalityGenerator::new(personality.clone());
    
    // 初始情感状态
    let mut current_emotion = EmotionalState {
        happiness: 0.5,
        affection: 0.3,
        trust: 0.3,
        dependency: 0.2,
        mood: "期待".to_string(),
        timestamp: chrono::Utc::now(),
    };
    
    println!("✅ 系统初始化完成！");
    println!("👧 MIRA: 你好呀~ 我是MIRA，你的AI女友！今天想聊什么呢？ (｡◕‿◕｡)\n");
    
    // 主要交互循环
    loop {
        // 显示用户输入提示
        print!("👤 你: ");
        io::stdout().flush().unwrap();
        
        // 读取用户输入
        let mut input = String::new();
        io::stdin().read_line(&mut input).unwrap();
        let user_input = input.trim();
        
        // 处理特殊命令
        match user_input.to_lowercase().as_str() {
            "quit" | "exit" => {
                println!("💕 MIRA: 再见呀~ 期待下次见面！(っ◔◡◔)っ ♥");
                break;
            }
            "help" => {
                show_help();
                continue;
            }
            "status" => {
                show_status(&memory_system, &current_emotion).await;
                continue;
            }
            "clear" => {
                // 清空记忆
                memory_system = MemorySystem::new(
                    "interactive_user".to_string(),
                    Arc::new(MockVectorStore::new()),
                    Some(memory_config.clone()),
                ).await?;
                println!("🧠 MIRA: 记忆已清空~ 我们重新开始吧！");
                continue;
            }
            "" => continue, // 空输入跳过
            _ => {}
        }
        
        println!("🤔 MIRA正在思考...");
        
        // 检索相关记忆
        let memories = memory_system.retrieve_memories(
            user_input,
            None,
            Some(3),
        ).await.unwrap_or_default();
        
        // 分析情感触发
        let triggers = emotional_engine.analyze_interaction(user_input, &memories);
        
        // 更新情感状态
        for (trigger, intensity) in triggers {
            current_emotion = emotional_engine.process_trigger(
                &current_emotion,
                trigger,
                intensity,
            );
        }
        
        // 生成回复
        let response = if python_client.health_check().await {
            // 使用Python推理服务生成智能回复
            match python_client.generate_response(
                user_input,
                memories.clone(),
                current_emotion.clone(),
            ).await {
                Ok(ai_response) => ai_response,
                Err(_) => {
                    // 后备回复生成
                    personality_generator.generate_personalized_response(
                        "收到你的消息了！",
                        user_input,
                    )
                }
            }
        } else {
            // 使用本地个性生成器
            personality_generator.generate_personalized_response(
                "听到了！",
                user_input,
            )
        };
        
        // 显示回复和情感状态
        println!("💕 MIRA: {}", response);
        println!("😊 [情感: {} | 开心={:.2}, 亲密={:.2}, 信任={:.2}]", 
            current_emotion.mood, 
            current_emotion.happiness, 
            current_emotion.affection, 
            current_emotion.trust
        );
        
        // 保存对话记忆
        let conversation = format!("用户说: {} | 我回复: {}", user_input, response);
        memory_system.add_memory(
            MemoryType::ShortTerm,
            conversation,
            vec![user_input.to_string()],
            0.5 + current_emotion.happiness * 0.3,
            Some(current_emotion.clone()),
        ).await.ok();
        
        // 更新记忆系统的情感状态
        memory_system.update_emotional_state(current_emotion.clone()).await;
        
        println!(); // 空行分隔
    }
    
    Ok(())
}

fn show_help() {
    println!("\n📚 MIRA 交互命令帮助");
    println!("====================");
    println!("💬 直接输入文字与MIRA聊天");
    println!("🆘 help     - 显示此帮助信息");
    println!("📊 status   - 查看系统和情感状态");
    println!("🧹 clear    - 清空记忆重新开始");
    println!("🚪 quit/exit - 退出程序");
    println!("====================\n");
}

async fn show_status(memory_system: &MemorySystem, emotion: &EmotionalState) {
    println!("\n📊 MIRA 系统状态");
    println!("================");
    
    // 显示记忆统计
    let stats = memory_system.get_memory_stats().await;
    println!("🧠 记忆统计:");
    for (memory_type, count) in stats.iter() {
        println!("   {:?}: {} 条", memory_type, count);
    }
    
    // 显示情感状态
    println!("💕 当前情感:");
    println!("   心情: {}", emotion.mood);
    println!("   开心程度: {:.2}", emotion.happiness);
    println!("   亲密程度: {:.2}", emotion.affection);
    println!("   信任程度: {:.2}", emotion.trust);
    println!("   依赖程度: {:.2}", emotion.dependency);
    println!("   情感均值: {:.2}", (emotion.happiness + emotion.affection + emotion.trust + emotion.dependency) / 4.0);
    
    // 显示服务状态
    let python_client = PythonInferenceClient::new("http://localhost:8000".to_string(), 10);
    let python_status = if python_client.health_check().await {
        "🟢 在线"
    } else {
        "🔴 离线"
    };
    
    println!("🔧 服务状态:");
    println!("   Python推理服务: {}", python_status);
    println!("   记忆系统: 🟢 正常");
    println!("   情感引擎: 🟢 正常");
    println!("================\n");
}
