# skills — ЕДИНОЕ место скиллов стенда/дома

Дата: **15.10.2026.** Сведено из `AGENT_SETTINGS\PROMPT\` (14) + `AGENT_SETTINGS\NOGA\` (1).
Прежние папки `PROMPT\` и `NOGA\` удалены — все скиллы уровня `AGENT_SETTINGS` теперь здесь.

## Что здесь (15 файлов)

| Скилл | О чём | было |
|---|---|---|
| `SKILL_criterion_needs_baseline.md` | критерий сравнивать с базой | PROMPT |
| `SKILL_ctx_limit_vs_section_limit.md` | потолок = `num_ctx`, не секция | PROMPT |
| `SKILL_fewshot_as_template.md` | few-shot как шаблон | PROMPT |
| `SKILL_full_block_noise_for_weak_model.md` | полный блок = шум для слабой модели | PROMPT |
| `SKILL_l6_checker_false_positive.md` | ложные срабатывания чекера | PROMPT |
| `SKILL_learning_new_direction.md` | как заводить новое направление | PROMPT |
| `SKILL_noga_health.md` | здоровье «ноги» (агентного канала) | **NOGA** |
| `SKILL_patch_fanout_anchor_first.md` | правки: сначала якорь | PROMPT |
| `SKILL_prompt_position_from_window.md` | позиция блока от окна (в токенах) | PROMPT |
| `SKILL_section_cut_silently.md` | раздел режется молча | PROMPT |
| `SKILL_seed_vs_temperature.md` | `temperature` меняет текст, не класс | PROMPT |
| `SKILL_stack_characterization.md` | характеризация стека моделей | PROMPT |
| `SKILL_stand_single_and_seed.md` | один прогон + фиксированный seed | PROMPT |
| `SKILL_tool_use_three_failures.md` | три типа провала вызова инструмента | PROMPT |
| `SKILL_verify_metric_on_known_answer.md` | метрику проверять на известном ответе | PROMPT |

## Что здесь НЕ лежит (и почему)

- **Скиллы стенда как документы** — остаются рядом с кодом тестов: `checks\agentic\SKILL_think_probe.md`, `checks\agentic\SKILL_cline_scheme.md`.
- **Тестовые пробы** — `AGENT_SETTINGS\probes\probe_0..9.ps1` (тестовые файлы и операции канала, папка отдельная).
- **Скиллы памяти дома** — `D:\AI\repo\PROMPT\` и `repo\agents\*`, `repo\AUDIT\*` (другой репозиторий, вне AGENT_SETTINGS).
- **Индекс по смыслу** — `D:\AI\tools\agent\skills_index\` (читает эти файлы, но базой не владеет).

## Правила
- Путь к папке — только из `config\paths.ps1` → `$CFG.SkillsDir` (не хардкодить).
- После правки скилла — пересобрать индекс: `python -X utf8 D:\AI\tools\agent\skills_index\skills_index.py build`.
