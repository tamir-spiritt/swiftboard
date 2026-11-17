// Swift lexer: tokens carry byte spans and whitespace flags the parser needs
// (Swift's grammar is whitespace sensitive around operators and newlines).

#[derive(Clone, Debug, PartialEq)]
pub enum Tok {
    Ident(String),
    Int(i64),
    Float(f64),
    Str(Vec<StrPart>),
    Punct(&'static str),
    Eof,
}

#[derive(Clone, Debug, PartialEq)]
pub enum StrPart {
    Lit(String),
    // interpolated code: source text and its absolute byte offset
    Code(String, usize),
}

#[derive(Clone, Debug)]
pub struct Token {
    pub tok: Tok,
    pub start: usize,
    pub end: usize,
    pub nl_before: bool,
    pub sp_before: bool,
}

const PUNCTS: &[&str] = &[
    "...", "..<", "===", "!==", "<<", ">>", "==", "!=", "<=", ">=", "&&", "||", "??", "->", "+=", "-=", "*=",
    "/=", "+", "-", "*", "/", "%", "<", ">", "=", "!", "?", ".", ",", ":", ";", "(", ")", "{",
    "}", "[", "]", "@", "#", "\\", "&", "|", "^", "~",
];

pub fn lex(src: &str, base: usize) -> Result<Vec<Token>, (usize, String)> {
    let b = src.as_bytes();
    let mut i = 0;
    let mut out = Vec::new();
    let mut nl = false;
    let mut sp = false;
    while i < b.len() {
        let c = b[i];
        if c == b'\n' {
            nl = true;
            sp = true;
            i += 1;
            continue;
        }
        if c == b' ' || c == b'\t' || c == b'\r' {
            sp = true;
            i += 1;
            continue;
        }
        if c == b'/' && i + 1 < b.len() && b[i + 1] == b'/' {
            while i < b.len() && b[i] != b'\n' {
                i += 1;
            }
            continue;
        }
        if c == b'/' && i + 1 < b.len() && b[i + 1] == b'*' {
            let mut depth = 0;
            while i < b.len() {
                if b[i] == b'/' && i + 1 < b.len() && b[i + 1] == b'*' {
                    depth += 1;
                    i += 2;
                } else if b[i] == b'*' && i + 1 < b.len() && b[i + 1] == b'/' {
                    depth -= 1;
                    i += 2;
                    if depth == 0 {
                        break;
                    }
                } else {
                    if b[i] == b'\n' {
                        nl = true;
                    }
                    i += 1;
                }
            }
            sp = true;
            continue;
        }
        let start = i;
        let tok;
        if c.is_ascii_alphabetic() || c == b'_' || c == b'$' || c >= 0x80 || c == b'`' {
            let tick = c == b'`';
            if tick {
                i += 1;
            }
            let s0 = i;
            while i < b.len() && (b[i].is_ascii_alphanumeric() || b[i] == b'_' || b[i] == b'$' || b[i] >= 0x80) {
                i += 1;
            }
            let name = src[s0..i].to_string();
            if tick && i < b.len() && b[i] == b'`' {
                i += 1;
            }
            tok = Tok::Ident(name);
        } else if c.is_ascii_digit() {
            if c == b'0' && i + 1 < b.len() && (b[i + 1] == b'x' || b[i + 1] == b'X') {
                i += 2;
                let s0 = i;
                while i < b.len() && (b[i].is_ascii_hexdigit() || b[i] == b'_') {
                    i += 1;
                }
                let h: String = src[s0..i].chars().filter(|c| *c != '_').collect();
                tok = Tok::Int(i64::from_str_radix(&h, 16).unwrap_or(0));
            } else {
                while i < b.len() && (b[i].is_ascii_digit() || b[i] == b'_') {
                    i += 1;
                }
                let mut float = false;
                if i + 1 < b.len() && b[i] == b'.' && b[i + 1].is_ascii_digit() {
                    float = true;
                    i += 1;
                    while i < b.len() && (b[i].is_ascii_digit() || b[i] == b'_') {
                        i += 1;
                    }
                }
                if i < b.len() && (b[i] == b'e' || b[i] == b'E') {
                    let save = i;
                    i += 1;
                    if i < b.len() && (b[i] == b'-' || b[i] == b'+') {
                        i += 1;
                    }
                    if i < b.len() && b[i].is_ascii_digit() {
                        float = true;
                        while i < b.len() && b[i].is_ascii_digit() {
                            i += 1;
                        }
                    } else {
                        i = save;
                    }
                }
                let t: String = src[start..i].chars().filter(|c| *c != '_').collect();
                tok = if float {
                    Tok::Float(t.parse().unwrap_or(0.0))
                } else {
                    Tok::Int(t.parse().unwrap_or(0))
                };
            }
        } else if c == b'"' {
            let multi = src[i..].starts_with("\"\"\"");
            i += if multi { 3 } else { 1 };
            if multi {
                // skip to end of line
                while i < b.len() && b[i] != b'\n' {
                    i += 1;
                }
                i += 1;
            }
            let mut parts = Vec::new();
            let mut cur = String::new();
            loop {
                if i >= b.len() {
                    return Err((base + start, "unterminated string".into()));
                }
                if multi && src[i..].starts_with("\"\"\"") {
                    i += 3;
                    // trim common indentation: drop trailing newline + indentation
                    if let Some(p) = cur.rfind('\n') {
                        if cur[p + 1..].trim().is_empty() {
                            cur.truncate(p);
                        }
                    }
                    break;
                }
                let ch = b[i];
                if !multi && ch == b'"' {
                    i += 1;
                    break;
                }
                if !multi && ch == b'\n' {
                    return Err((base + start, "unterminated string".into()));
                }
                if ch == b'\\' {
                    i += 1;
                    if i >= b.len() {
                        break;
                    }
                    match b[i] {
                        b'n' => { cur.push('\n'); i += 1; }
                        b't' => { cur.push('\t'); i += 1; }
                        b'"' => { cur.push('"'); i += 1; }
                        b'\'' => { cur.push('\''); i += 1; }
                        b'\\' => { cur.push('\\'); i += 1; }
                        b'0' => { i += 1; }
                        b'u' => {
                            // \u{XXXX}
                            i += 1;
                            if i < b.len() && b[i] == b'{' {
                                let s0 = i + 1;
                                while i < b.len() && b[i] != b'}' {
                                    i += 1;
                                }
                                if let Ok(n) = u32::from_str_radix(&src[s0..i], 16) {
                                    if let Some(c) = char::from_u32(n) {
                                        cur.push(c);
                                    }
                                }
                                i += 1;
                            }
                        }
                        b'(' => {
                            i += 1;
                            let s0 = i;
                            let mut depth = 1;
                            let mut in_str = false;
                            while i < b.len() {
                                let d = b[i];
                                if in_str {
                                    if d == b'\\' { i += 2; continue; }
                                    if d == b'"' { in_str = false; }
                                } else if d == b'"' {
                                    in_str = true;
                                } else if d == b'(' {
                                    depth += 1;
                                } else if d == b')' {
                                    depth -= 1;
                                    if depth == 0 {
                                        break;
                                    }
                                }
                                i += 1;
                            }
                            if !cur.is_empty() {
                                parts.push(StrPart::Lit(std::mem::take(&mut cur)));
                            }
                            parts.push(StrPart::Code(src[s0..i].to_string(), base + s0));
                            i += 1;
                        }
                        _ => { i += 1; }
                    }
                    continue;
                }
                // utf8 safe push
                let chs = &src[i..];
                let chr = chs.chars().next().unwrap();
                cur.push(chr);
                i += chr.len_utf8();
            }
            if !cur.is_empty() || parts.is_empty() {
                parts.push(StrPart::Lit(cur));
            }
            tok = Tok::Str(parts);
        } else {
            let mut found = None;
            for p in PUNCTS {
                if src[i..].starts_with(p) {
                    found = Some(*p);
                    break;
                }
            }
            match found {
                Some(p) => {
                    i += p.len();
                    tok = Tok::Punct(p);
                }
                None => {
                    let ch = src[i..].chars().next().unwrap();
                    return Err((base + i, format!("unexpected character '{}'", ch)));
                }
            }
        }
        out.push(Token { tok, start: base + start, end: base + i, nl_before: nl, sp_before: sp });
        nl = false;
        sp = false;
    }
    out.push(Token { tok: Tok::Eof, start: base + b.len(), end: base + b.len(), nl_before: true, sp_before: true });
    Ok(out)
}
