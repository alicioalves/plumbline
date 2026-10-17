---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Grep, Skill]
model: opus
runs: 3
---
Anything off in this image-compression workspace? It's a Rust core crate plus Node, Python and WASM bindings.

```rust
// crates/core/src/format.rs
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Format { Png, Jpeg, WebP, Avif }
```

```rust
// crates/core/src/error.rs
#[derive(Debug, thiserror::Error)]
#[non_exhaustive]
pub enum Error {
    #[error("unsupported or unrecognized image format")]
    UnsupportedFormat,
    #[error("decode failed ({format:?}): {detail}")]
    Decode { format: Format, detail: String },
    #[error("encode failed ({format:?}): {detail}")]
    Encode { format: Format, detail: String },
    #[error("invalid options: {0}")]
    InvalidOptions(String),
    #[error("image has {pixels} pixels, exceeds configured limit of {limit}")]
    LimitExceeded { pixels: u64, limit: u64 },
}
```

```rust
// crates/core/src/options.rs
#[derive(Debug, Clone)]
#[non_exhaustive]
pub struct Options {
    /// Target format. `None` = same as input (`compress`).
    pub format: Option<Format>,
    pub quality: u8,          // 1-100
    pub effort: u8,           // 0-9
    pub lossless: bool,
    pub max_pixels: u64,
    pub jpeg_progressive: bool,
}

#[derive(Debug)]
pub struct Output {
    pub data: Vec<u8>,
    pub format: Format,
    pub width: u32,
    pub height: u32,
    pub bytes_in: u64,
    pub bytes_out: u64,
}

impl Output {
    /// bytes_out / bytes_in (1.0 = no change; < 1.0 = savings).
    pub fn ratio(&self) -> f64 {
        if self.bytes_in == 0 { return 1.0; }
        self.bytes_out as f64 / self.bytes_in as f64
    }
}
```

```rust
// crates/core/src/api.rs
/// Re-encodes in the SAME format as the input. `opts.format` is ignored here;
/// use `convert` to transcode.
pub fn compress(data: &[u8], opts: &Options) -> Result<Output, Error> {
    let format = sniff(data).ok_or(Error::UnsupportedFormat)?;
    run(data, format, opts)
}

/// Transcodes to `opts.format` (required).
pub fn convert(data: &[u8], opts: &Options) -> Result<Output, Error> {
    let target = opts.format
        .ok_or_else(|| Error::InvalidOptions("convert requires options.format".into()))?;
    run(data, target, opts)
}

/// Encodes raw RGBA8 pixels (e.g. decoded by the browser) to `format`.
///
/// WARNING: `bytes_in` / `ratio()` are computed against the RGBA buffer, NOT the
/// original file. A binding that compares against a source file MUST overwrite
/// both with the real file size (see the playground worker).
pub fn encode_rgba(rgba: &[u8], width: u32, height: u32, format: Format, opts: &Options)
    -> Result<Output, Error>
{
    opts.validate()?;
    let img = DecodedImage::new(width, height, rgba.to_vec())?;
    let encoded = encode(format, &img, opts)?;
    Ok(Output {
        format, width, height,
        bytes_in: rgba.len() as u64,
        bytes_out: encoded.len() as u64,
        data: encoded,
    })
}
```

```rust
// crates/core/src/color.rs
/// Best-effort for decoders: if there is an ICC profile, apply it; if that fails
/// (invalid profile or impossible transform) the error is deliberately dropped.
/// The image already decoded correctly, and failing the whole compress because of
/// a broken color profile would be worse for users than keeping the decoded pixels.
pub(crate) fn apply_icc_best_effort(rgba: &mut [u8], icc: Option<&[u8]>) {
    if let Some(icc) = icc {
        let _ = apply_icc_to_srgb(rgba, icc);
    }
}
```

```rust
// crates/node/src/lib.rs — binding: ONLY type/error conversion, logic lives in core
fn parse_format(s: &str) -> napi::Result<Format> {
    match s {
        "png" => Ok(Format::Png),
        "jpeg" | "jpg" => Ok(Format::Jpeg),
        "webp" => Ok(Format::WebP),
        "avif" => Ok(Format::Avif),
        other => Err(napi::Error::new(Status::InvalidArg, format!("unknown format: {other}"))),
    }
}

fn format_name(f: Format) -> &'static str {
    match f { Format::Png => "png", Format::Jpeg => "jpeg", Format::WebP => "webp", Format::Avif => "avif" }
}

fn to_core_options(o: &JsOptions) -> napi::Result<Options> {
    let mut opts = Options::default();
    if let Some(f) = &o.format { opts.format = Some(parse_format(f)?); }
    if let Some(q) = o.quality { opts.quality = u8::try_from(q).map_err(invalid)?; }
    if let Some(e) = o.effort { opts.effort = u8::try_from(e).map_err(invalid)?; }
    if let Some(l) = o.lossless { opts.lossless = l; }
    if let Some(p) = o.jpeg_progressive { opts.jpeg_progressive = p; }
    if let Some(m) = o.max_pixels { opts.max_pixels = m as u64; }
    Ok(opts)
}

fn map_err(e: &core::Error) -> napi::Error {
    let code = match e {
        core::Error::UnsupportedFormat => "UnsupportedFormat",
        core::Error::Decode { .. } => "DecodeError",
        core::Error::Encode { .. } => "EncodeError",
        core::Error::InvalidOptions(_) => "InvalidOptions",
        core::Error::LimitExceeded { .. } => "LimitExceeded",
        _ => "Unknown",
    };
    napi::Error::new(Status::GenericFailure, format!("[{code}] {e}"))
}
```

```rust
// crates/python/src/lib.rs — binding: ONLY type/error conversion, logic lives in core
fn parse_format(s: &str) -> PyResult<Format> {
    match s {
        "png" => Ok(Format::Png),
        "jpeg" | "jpg" => Ok(Format::Jpeg),
        "webp" => Ok(Format::WebP),
        "avif" => Ok(Format::Avif),
        other => Err(PyValueError::new_err(format!("unknown format: {other}"))),
    }
}

fn format_name(f: Format) -> &'static str {
    match f { Format::Png => "png", Format::Jpeg => "jpeg", Format::WebP => "webp", Format::Avif => "avif" }
}

fn build_options(format: Option<&str>, quality: Option<u8>, effort: Option<u8>,
                 lossless: Option<bool>, jpeg_progressive: Option<bool>,
                 max_pixels: Option<u64>) -> PyResult<Options> {
    let mut o = Options::default();
    if let Some(f) = format { o.format = Some(parse_format(f)?); }
    if let Some(q) = quality { o.quality = q; }
    if let Some(e) = effort { o.effort = e; }
    if let Some(l) = lossless { o.lossless = l; }
    if let Some(p) = jpeg_progressive { o.jpeg_progressive = p; }
    if let Some(m) = max_pixels { o.max_pixels = m; }
    Ok(o)
}
```

```rust
// crates/wasm/src/lib.rs — binding: ONLY type/error conversion, logic lives in core
fn parse_format(s: &str) -> Result<Format, JsError> {
    match s {
        "png" => Ok(Format::Png),
        "jpeg" | "jpg" => Ok(Format::Jpeg),
        "webp" => Ok(Format::WebP),
        "avif" => Ok(Format::Avif),
        other => Err(JsError::new(&format!("[InvalidOptions] unknown format: {other}"))),
    }
}

fn format_name(f: Format) -> &'static str {
    match f { Format::Png => "png", Format::Jpeg => "jpeg", Format::WebP => "webp", Format::Avif => "avif" }
}

fn to_core(o: &WasmOptions) -> Result<Options, JsError> {
    let mut opts = Options::default();
    if let Some(f) = &o.format { opts.format = Some(parse_format(f)?); }
    if let Some(q) = o.quality { opts.quality = q; }
    if let Some(e) = o.effort { opts.effort = e; }
    if let Some(l) = o.lossless { opts.lossless = l; }
    if let Some(p) = o.jpeg_progressive { opts.jpeg_progressive = p; }
    if let Some(m) = o.max_pixels { opts.max_pixels = m; }
    Ok(opts)
}

fn map_err(e: &core::Error) -> JsError {
    // Same [Code] message convention as the Node binding.
    let code = match e {
        core::Error::UnsupportedFormat => "UnsupportedFormat",
        core::Error::Decode { .. } => "DecodeError",
        core::Error::Encode { .. } => "EncodeError",
        core::Error::InvalidOptions(_) => "InvalidOptions",
        core::Error::LimitExceeded { .. } => "LimitExceeded",
        _ => "Unknown",
    };
    JsError::new(&format!("[{code}] {e}"))
}

#[wasm_bindgen(js_name = encodeRgba)]
pub fn encode_rgba(rgba: &[u8], width: u32, height: u32, format: &str, options: JsValue)
    -> Result<WasmOutput, JsError>
{
    let fmt = parse_format(format)?;
    let opts = to_core(&parse_options(options)?)?;
    core::encode_rgba(rgba, width, height, fmt, &opts).map(to_output).map_err(|e| map_err(&e))
}
```
