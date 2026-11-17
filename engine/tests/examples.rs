//! Renders every bundled example app and drives a few interactions end to end.

use std::path::Path;
use swiftboard::Instance;

fn load(dir: &Path) -> Instance {
    let mut files: Vec<_> = std::fs::read_dir(dir).unwrap().filter_map(|e| e.ok()).map(|e| e.path()).filter(|p| p.extension().map_or(false, |x| x == "swift")).collect();
    files.sort();
    let src: String = files.iter().map(|f| std::fs::read_to_string(f).unwrap() + "\n").collect();
    let mut i = Instance::new();
    let r = i.set_source(&src);
    assert!(r.contains("\"ok\":true"), "{} failed to compile: {}", dir.display(), r);
    i
}

fn previews(i: &mut Instance) -> Vec<String> {
    let it = i.interp.as_ref().unwrap();
    let mut v: Vec<String> = it.previews.iter().map(|p| p.0.to_string()).collect();
    if v.is_empty() {
        v.push(String::new());
    }
    v
}

fn tap_text(i: &mut Instance, t: &str) {
    i.render();
    let (r, _) = i.texts.iter().find(|x| x.1 == t).unwrap_or_else(|| panic!("no text {:?} on screen", t)).clone();
    let res = i.tap(r.x + r.w / 2.0, r.y + r.h / 2.0);
    assert!(!res.contains("error"), "tap {:?}: {}", t, res);
}

fn screen(i: &mut Instance) -> Vec<String> {
    i.render();
    i.texts.iter().map(|x| x.1.clone()).collect()
}

#[test]
fn every_example_renders_without_errors() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../examples");
    let mut dirs: Vec<_> = std::fs::read_dir(&root).unwrap().filter_map(|e| e.ok()).map(|e| e.path()).filter(|p| p.is_dir()).collect();
    dirs.sort();
    assert!(dirs.len() >= 7);
    for d in dirs {
        let mut i = load(&d);
        for p in previews(&mut i) {
            i.preview = p.clone();
            let out = i.render();
            assert!(!out.starts_with("{\"error\""), "{} / {}: {}", d.display(), p, &out[..out.len().min(300)]);
            assert!(out.contains("\"errors\":[]"), "{} / {} reported errors", d.display(), p);
            assert!(!i.texts.is_empty(), "{} / {} drew no text", d.display(), p);
        }
    }
}

#[test]
fn calculator_multiplies() {
    let mut i = load(&Path::new(env!("CARGO_MANIFEST_DIR")).join("../examples/04-Calculator"));
    for k in ["7", "×", "6", "="] {
        tap_text(&mut i, k);
    }
    assert!(screen(&mut i).contains(&"42".to_string()));
}

#[test]
fn todo_playground_state_and_text_input() {
    let mut i = load(&Path::new(env!("CARGO_MANIFEST_DIR")).join("../examples/03-TodoPlayground"));
    for _ in 0..4 {
        tap_text(&mut i, "+");
    }
    let s = screen(&mut i);
    assert!(s.contains(&"Count: 4".to_string()));
    assert!(s.contains(&"That's a lot of taps".to_string()));
    // focus the text field, type, add
    let inp = i.inputs[0].rect;
    i.tap(inp.x + 4.0, inp.y + inp.h / 2.0);
    i.input("Buy milk");
    tap_text(&mut i, "Add");
    assert!(screen(&mut i).contains(&"Buy milk".to_string()));
}

#[test]
fn messenger_navigation_and_send() {
    let mut i = load(&Path::new(env!("CARGO_MANIFEST_DIR")).join("../examples/01-Messenger"));
    i.preview = "Chat List".into();
    tap_text(&mut i, "Design Team");
    assert!(screen(&mut i).contains(&"5 members, 2 online".to_string()), "chat did not open");
    let inp = i.inputs[0].rect;
    i.tap(inp.x + 4.0, inp.y + inp.h / 2.0);
    i.input("Hello from Swift");
    i.submit();
    assert!(screen(&mut i).contains(&"Hello from Swift".to_string()));
}

#[test]
fn compile_errors_point_at_source() {
    let mut i = Instance::new();
    let r = i.set_source("struct A: View {\n  var body: some View { Text(\"x\" }\n}");
    assert!(r.contains("\"ok\":false"));
    assert!(r.contains("\"pos\""));
}
