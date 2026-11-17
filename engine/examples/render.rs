use swiftboard::Instance;
fn main() {
    let dir = std::env::args().nth(1).unwrap_or("../examples/01-Messenger".into());
    let mut files: Vec<_> = std::fs::read_dir(&dir).unwrap().filter_map(|e| e.ok()).map(|e| e.path()).filter(|p| p.extension().map(|x| x == "swift").unwrap_or(false)).collect();
    files.sort();
    let mut src = String::new();
    let mut offs = vec![];
    for f in &files { offs.push((src.len(), f.file_name().unwrap().to_string_lossy().to_string())); src.push_str(&std::fs::read_to_string(f).unwrap()); src.push('\n'); }
    let loc = |pos: usize| { let (o, n) = offs.iter().rev().find(|(o, _)| *o <= pos).unwrap(); let line = src[*o..pos].matches('\n').count() + 1; format!("{}:{}", n, line) };
    let mut inst = Instance::new();
    let r = inst.set_source(&src);
    println!("compile: {}", &r[..r.len().min(300)]);
    if r.contains("\"ok\":false") { let p: usize = r.split("\"pos\":").nth(1).unwrap().split(',').next().unwrap().parse().unwrap(); println!("at {}", loc(p)); return; }
    let previews: Vec<String> = std::env::args().skip(2).collect();
    let list = if previews.is_empty() { vec!["Chat List".to_string(), "Chat".into(), "Contacts".into(), "Calls".into(), "Settings".into()] } else { previews };
    for pv in list {
        inst.preview = pv.clone();
        let t = std::time::Instant::now();
        let out = inst.render();
        let dt = t.elapsed();
        if out.starts_with("{\"error\"") { let p: usize = out.split("\"pos\":").nth(1).unwrap().split(',').next().unwrap().parse().unwrap(); println!("[{}] ERROR {} at {}", pv, &out[..out.len().min(300)], loc(p)); continue; }
        let nops = out.matches("[\"").count();
        let errs = out.split("\"errors\":[").nth(1).unwrap().split("],\"inputs\"").next().unwrap();
        let warns = out.split("\"warnings\":[").nth(1).unwrap();
        println!("[{}] {} ops, {} bytes, {:?}, hits {} errs={} warns={}", pv, nops, out.len(), dt, inst.hits.len(), &errs[..errs.len().min(300)], &warns[..warns.len().min(400)]);
        if std::env::var("DUMP").is_ok() { println!("{}", &out[..out.len().min(6000)]); }
    }
}
