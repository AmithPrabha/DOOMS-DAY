"""Generate a standalone, searchable, accessible offline HTML maintenance guide."""
import html
import json
import re
from pathlib import Path
from check import ROOT, build_id

def inline(text):
    escaped=html.escape(text)
    escaped=re.sub(r'`([^`]+)`',r'<code>\1</code>',escaped)
    escaped=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',lambda m:
        f'<a href="{m[2]}">{m[1]}</a>',escaped)
    return escaped

def markdown(text):
    parts=[]; paragraph=[]; listing=False; code=None; table=[]
    def flush():
        nonlocal listing
        if paragraph:parts.append("<p>"+inline(" ".join(paragraph))+"</p>");paragraph.clear()
        if listing:parts.append("</ul>");listing=False
        if table:
            rows=[row.strip().strip("|").split("|") for row in table]
            parts.append("<div class='table-wrap'><table><thead><tr>"+''.join(f"<th>{inline(c.strip())}</th>" for c in rows[0])+"</tr></thead><tbody>")
            for row in rows[2:]:parts.append("<tr>"+''.join(f"<td>{inline(c.strip())}</td>" for c in row)+"</tr>")
            parts.append("</tbody></table></div>");table.clear()
    for line in text.splitlines():
        if line.startswith("```"):
            if code is None:flush();code=[]
            else:parts.append("<pre><code>"+html.escape("\n".join(code))+"</code></pre>");code=None
        elif code is not None:code.append(line)
        elif line.startswith("|"):table.append(line)
        elif line.startswith("#"):
            flush();level=min(len(line)-len(line.lstrip("#")),4)
            parts.append(f"<h{level}>{inline(line[level:].strip())}</h{level}>")
        elif line.startswith("- "):
            if paragraph:parts.append("<p>"+inline(" ".join(paragraph))+"</p>");paragraph.clear()
            if not listing:parts.append("<ul>");listing=True
            parts.append("<li>"+inline(line[2:])+"</li>")
        elif not line.strip():flush()
        else:paragraph.append(line)
    flush();return "\n".join(parts)

def table(rows,keys):
    out="<div class='table-wrap'><table><thead><tr>"+''.join(f"<th>{html.escape(k.replace('_',' ').title())}</th>" for k in keys)+"</tr></thead><tbody>"
    for row in rows:
        out+="<tr>"
        for key in keys:
            value=row.get(key,"")
            if isinstance(value,list):value=", ".join(str(v) for v in value)
            text=html.escape(str(value))
            if key in ["source","implementation"]:text=f'<a href="../{text}">{text}</a>'
            if key=="url":text=f'<a href="{text}">Official requirement</a>'
            out+=f"<td>{text}</td>"
        out+="</tr>"
    return out+"</tbody></table></div>"

def flow_diagrams():
    flows=[
        ("Startup",["Entrypoint","App support directory","Drift migration","Essential handbook + preferences","Riverpod providers","Emergency screen"]),
        ("Reading and search",["User query","LibraryScreen debounce","KnowledgeRepository","SQLite FTS5 / BM25","Paged results","ArticleScreen"]),
        ("Explicit online save",["Choose online search","Wikipedia API","Parse supported text","License + revision + budget checks","Atomic SQLite save","Offline Library search"]),
        ("Quick controls",["Header or Settings","PreferencesController","Immediate UI update","Serialized SQLite write","Restore committed values on failure"]),
        ("Download and recovery",["Choose pack","Budget + free space","Resumable .part file","Hash + content checks","Immutable directory","Database transaction","Installed content"]),
        ("Map and sensors",["Map screen","Verify installed files","Local PMTiles + style","MapLibre renderer","Locate / magnetic heading"]),
    ]
    result="<h2>Flow diagrams</h2>"
    for title,steps in flows:
        result+=f"<h3>{html.escape(title)}</h3><ol class='flow'>"+''.join(f"<li>{html.escape(step)}</li>" for step in steps)+"</ol>"
    return result+"<p>A failed download returns to its resumable file; a failed activation keeps the prior database pointer. User bookmarks and preferences remain separate.</p>"

def generate():
    load=lambda f:json.loads((ROOT/"registry"/f).read_text())
    feature_html=markdown((ROOT/"docs/upgrade.md").read_text())+"<h1>Feature register</h1><p>Every feature links to its source and acceptance cases. Status describes implementation, not store approval.</p>"+table(load("features.json"),["id","title","status","dependencies","source","tests","notes"])
    tests=markdown((ROOT/"docs/testing.md").read_text())+markdown((ROOT/"docs/build-evidence.md").read_text())+table(load("test_cases.json"),["id","title","type","feature_ids","prerequisites","steps","platforms","source","expected"])
    results=load("results.json")
    tests+=f"<h2>Recorded results</h2><p>Build: {html.escape(str(results['build']))}</p>"+table(results["results"],["id","status","evidence"])
    sections=[("features","Features",feature_html)]
    for id,title,file in [("flow","App Flow","architecture.md"),("build","Build & Tools","build.md"),("code","Code & Data","code.md")]:
        sections.append((id,title,(flow_diagrams() if id=="flow" else "")+markdown((ROOT/"docs"/file).read_text())))
    sections.append(("tests","Tests",tests))
    for id,title,file in [("troubleshooting","Troubleshooting","troubleshooting.md"),("content","Content & Languages","content.md"),("release","Release","release.md")]:
        body=markdown((ROOT/"docs"/file).read_text())
        if id=="content":
            articles=json.loads((ROOT/"assets/content/essential.json").read_text())["articles"] + json.loads((ROOT/"assets/content/practical.json").read_text())["articles"]
            body+="<h2>Practical coverage</h2><pre>"+html.escape(json.dumps(load("content_coverage.json"),indent=2))+"</pre>"
            body+="<h2>Bundled article inventory</h2>"+table(articles,["id","title","language","category","level","review_status"])
        if id=="release":body+=table(load("policies.json"),["id","title","verified_at","status","applicability","implementation","outstanding_actions","evidence","url"])
        sections.append((id,title,body))
    tabs=''.join(f'<button role="tab" id="tab-{id}" aria-controls="{id}" aria-selected="{str(i==0).lower()}" tabindex="{0 if i==0 else -1}" data-tab="{id}">{title}</button>' for i,(id,title,_) in enumerate(sections))
    bodies=''.join(f'<section role="tabpanel" id="{id}" aria-labelledby="tab-{id}" {"hidden" if i else ""}>{body}</section>' for i,(id,_,body) in enumerate(sections))
    output=f"""<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Dooms Day App · Maintenance guide</title>
<style>
:root{{color-scheme:light dark;--bg:#f5f3ec;--card:#fff;--ink:#233c31;--line:#dce3d7;--muted:#627567}}
*{{box-sizing:border-box}}body{{margin:0;background:var(--bg);color:var(--ink);font:16px/1.6 system-ui,sans-serif}}
header{{padding:40px max(24px,calc((100vw - 1200px)/2));background:#244d40;color:#fff}}
header b{{letter-spacing:4px;font-size:14px}}header h1{{font-size:clamp(28px,5vw,48px);margin:10px 0}}header p{{max-width:760px;color:#d7e6cb}}
main{{max-width:1250px;margin:auto;padding:24px}}nav{{display:flex;gap:8px;flex-wrap:wrap;margin:18px 0 28px}}
button{{border:1px solid var(--line);background:var(--card);color:var(--ink);border-radius:24px;padding:12px 18px;font:inherit;cursor:pointer}}
button[aria-selected=true]{{background:#244d40;color:white}}input{{width:100%;padding:16px;border:1px solid var(--line);border-radius:12px;font:inherit;background:var(--card);color:var(--ink)}}
section{{background:var(--card);padding:clamp(18px,4vw,40px);border-radius:20px}}section+section{{margin-top:20px}}
h1,h2,h3{{line-height:1.25}}h2{{margin-top:32px}}a{{color:#287460;overflow-wrap:anywhere}}a:focus,button:focus,input:focus{{outline:3px solid #b77a24;outline-offset:3px}}
.flow{{display:flex;flex-wrap:wrap;gap:24px;padding:0;list-style:none}}.flow li{{background:var(--bg);border:1px solid var(--line);border-radius:10px;padding:12px;position:relative;max-width:200px}}.flow li:not(:last-child)::after{{content:'→';position:absolute;right:-21px}}
table{{border-collapse:collapse;width:100%;font-size:14px}}th,td{{text-align:left;vertical-align:top;border-bottom:1px solid var(--line);padding:14px 10px;min-width:90px}}th{{background:var(--bg)}}.table-wrap{{overflow:auto}}pre{{overflow:auto;padding:20px;background:var(--bg);border-radius:12px}}code{{font-size:.9em}}footer{{padding:30px;color:var(--muted)}}[hidden]{{display:none!important}}
@media(prefers-color-scheme:dark){{:root{{--bg:#14211b;--card:#203329;--ink:#e6efdf;--line:#3c5143;--muted:#bccdbb}}a{{color:#a4d4b5}}}}
@media print{{nav,input,header p{{display:none}}section[hidden]{{display:block!important}}section{{break-before:page}}}}
</style>
<header><b>DOOMS DAY APP / ENGINEERING HANDBOOK</b><h1>Understand it. Test it. Maintain it.</h1>
<p>Your offline reference to the app's features, data flow, tools, tests and release requirements. Draft content and missing evidence remain visible.</p></header>
<main><label for="search">Search the maintenance guide</label><input id="search" type="search" placeholder="Try: search, maps, migration, translation…">
<nav role="tablist" aria-label="Guide sections">{tabs}</nav><p id="status" role="status"></p>{bodies}</main>
<footer>Generated from repository documents · build {build_id()} · works offline · external policy links require internet.</footer>
<script>
const tabs=[...document.querySelectorAll('[role=tab]')],panels=[...document.querySelectorAll('[role=tabpanel]')],search=document.querySelector('#search');
function select(id){{search.value='';document.querySelector('#status').textContent='';tabs.forEach(t=>{{let active=t.dataset.tab===id;t.setAttribute('aria-selected',active);t.tabIndex=active?0:-1}});panels.forEach(p=>p.hidden=p.id!==id);history.replaceState(null,'','#'+id)}}
tabs.forEach((t,i)=>{{t.onclick=()=>select(t.dataset.tab);t.onkeydown=e=>{{if(['ArrowLeft','ArrowRight','Home','End'].includes(e.key)){{e.preventDefault();let n=e.key==='Home'?0:e.key==='End'?tabs.length-1:(i+(e.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;select(tabs[n].dataset.tab);tabs[n].focus()}}}}}});
search.oninput=()=>{{let q=search.value.toLowerCase().trim();if(!q){{select(tabs.find(t=>t.getAttribute('aria-selected')==='true').dataset.tab);return}}let count=0;panels.forEach(p=>{{p.hidden=!p.textContent.toLowerCase().includes(q);if(!p.hidden)count++}});document.querySelector('#status').textContent=count+' matching sections'}};
if(tabs.some(t=>t.dataset.tab===location.hash.slice(1)))select(location.hash.slice(1));
</script></html>"""
    (ROOT/"docs/guide.html").write_text(output)
    return output
if __name__=="__main__":generate();print("Generated docs/guide.html")
