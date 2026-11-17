use swiftboard::Instance;
fn main() {
    let dir = std::env::args().nth(1).unwrap();
    let src: String = std::fs::read_dir(&dir).unwrap().filter_map(|e| e.ok()).map(|e| std::fs::read_to_string(e.path()).unwrap()).collect::<Vec<_>>().join("\n");
    let mut i = Instance::new();
    println!("{}", i.set_source(&src));
    let tap_text = |i: &mut Instance, t: &str| { i.render(); let all: Vec<(f64,f64,f64,f64,String)> = i.texts.iter().map(|(r,t)| (r.x,r.y,r.w,r.h,t.clone())).collect(); let e = all.iter().find(|x| x.4 == t).unwrap_or_else(|| panic!("no text {} in {:?}", t, all.iter().map(|x| &x.4).collect::<Vec<_>>())); let r = i.tap(e.0 + e.2/2.0, e.1 + e.3/2.0); println!("tap {:?} -> {}", t, r); };
    for _ in 0..4 { tap_text(&mut i, "+"); }
    tap_text(&mut i, "Sleep");
    tap_text(&mut i, "Active");
    i.render();
    println!("after: {:?}", i.texts.iter().map(|x| x.1.clone()).collect::<Vec<_>>());
    tap_text(&mut i, "All");
    // focus text field
    let out = i.render();
    let inp = out.split("\"inputs\":[[").nth(1).unwrap();
    let n: Vec<f64> = inp.split(',').take(4).map(|x| x.parse().unwrap()).collect();
    println!("focus -> {}", &i.tap(n[0] + 5.0, n[1] + n[3]/2.0)[..40]);
    i.input("Buy milk");
    tap_text(&mut i, "Add");
    let out = i.render();
    println!("final: {:?}", i.texts.iter().map(|x| x.1.clone()).collect::<Vec<_>>());
    if out.contains("\"error\"") { println!("ERR {}", &out[..300]); }
}
