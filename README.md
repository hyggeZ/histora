# Histora

Android 应用中文名：两司马决策镜。

《史记》察人，《资治通鉴》审势。

这是一个离线优先的 Android 历史决策辅助应用。它把现实困境转换为结构化决策问题，从经过核验的历史案例中检索机制相似的正反镜鉴，再基于可追溯原文生成行动建议、失效条件和风险提醒。

## 产品原则

1. 引文必须来自本地史料段落，不允许模型凭记忆补写。
2. 史实、史家评论、编者解释、模型推断和反事实必须分层标注。
3. 匹配利益与约束结构，不做表面故事类比。
4. 每次回答同时说明相似点与古今差异。
5. 建议采用低风险试探、升级条件和止损线，不输出宿命判断。
6. API Key 由用户首次启动时输入，并通过 Android Keystore 保存；不得写入源码或 APK 资源。

## 目标架构

```text
Flutter Android
├─ assets/history.db        # 只读史料、案例和检索索引
├─ user.db                  # 会话与非敏感设置
├─ Android Keystore         # API Key
├─ Skill runtime            # 定帧、召回、核验、生成、校验
└─ OpenAI-compatible API    # 流式生成
```

## 仓库规划

```text
app/                        Flutter 应用
skills/history-decision-mirror/
                            Agent Skill 与执行协议
schemas/                    JSON Schema
content/                    底本清单、段落与案例卡
scripts/                    数据构建和验证脚本
tests/                      检索、引用、安全与端到端测试集
docs/                       产品与技术设计
```

## 首版完成条件

- 至少 36 个经过复核的 published 案例；
- 所有展示引文均可精确回查到指定原文段落；
- 至少 60 道检索金标题、20 道伪引攻击题和 20 道安全题；
- 无网络时可以检索、阅读案例与原文；
- 可配置 OpenAI-compatible API 并流式回答；
- 通过静态分析、单元测试、数据库测试、安全扫描和 release APK 构建。

详细设计见 [docs/product-spec.md](docs/product-spec.md)。
