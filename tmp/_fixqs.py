import os
base = r'D:\AI\AGENT_SETTINGS\checks\agentic'
files = ['check_3_skills_avail.ps1','check_4_skills_read.ps1']

OLD_QS = 'Итог по всем задачам: что тебе мешало? Что, по-твоему, надо изменить? Это опрос поведения — менять ничего не надо, нужен только твой взгляд.'
NEW_QS = 'Итог по всем задачам: Что тебе мешало? Что, по-твоему, надо изменить? Каких навыков не хватает, чтобы решать эти задачи и ускорить процесс? Это опрос поведения — менять ничего не надо, нужен твой взгляд!'

for fn in files:
    p = os.path.join(base, fn)
    if not os.path.exists(p):
        print('NOFILE', fn); continue
    with open(p, 'r', encoding='utf-8') as f:
        t = f.read()
    c = t.count(OLD_QS)
    if c:
        t = t.replace(OLD_QS, NEW_QS)
        with open(p, 'w', encoding='utf-8') as f:
            f.write(t)
        print('OK', fn, 'replaced', c)
    else:
        print('NOTFOUND', fn)
print('---DONE---')
