/// Value types produced by the parser and consumed by later compiler stages.
///
/// # Lifecycle
///
/// `parse` → [`TemplateValue`]  
/// `render` (stack substitution resolved) → [`ProgramValue`]  
/// `execute` → [`DataValue`] written to the data stack
///
/// Templates ([`TemplateData`]) cannot be placed on the data stack directly,
/// but a [`RealValue::Substack`] that *contains* them can be passed around
/// freely; the template is rendered when the substack is invoked.

/// A concrete, fully-realised value.
///
/// Maps directly onto C-compatible primitive types plus structured
/// collections, so code-gen can target them without an intermediate
/// representation layer.
#[derive(Debug, Clone, PartialEq)]
pub enum RealValue {
    Bool(bool),
    Int(i64),
    Float(f64),
    /// A unicode grapheme cluster (may be multi-codepoint, e.g. emoji).
    Char(String),
    Str(String),
    List(Vec<DataValue>),
    Substack(Vec<ProgramValue>),
}

/// A value as it sits on the data stack — either a concrete value or an
/// unresolved label that will be looked up in scope at execution time.
#[derive(Debug, Clone, PartialEq)]
pub enum DataValue {
    Real(RealValue),
    Label(String),
}
impl From<RealValue> for DataValue {
    fn from(v: RealValue) -> Self { Self::Real(v) }
}

/// A value as it appears in a parsed program sequence — concrete values,
/// labels, an invoke instruction, or a template waiting for stack/scope
/// substitution.
#[derive(Debug, Clone, PartialEq)]
pub enum ProgramValue {
    Real(RealValue),
    Label(String),
    Invoke,
    Template(Template),
}
impl From<RealValue> for ProgramValue {
    fn from(v: RealValue) -> Self { Self::Real(v) }
}
impl From<DataValue> for ProgramValue {
    fn from(v: DataValue) -> Self {
        match v {
            DataValue::Real(r) => Self::Real(r),
            DataValue::Label(l) => Self::Label(l),
        }
    }
}
impl From<Template> for ProgramValue {
    fn from(t: Template) -> Self { Self::Template(t) }
}

/// A nestable literal that may contain [`TemplateValue`]s referencing the
/// parent stack or scope.  Carries the count of parent-stack entries consumed
/// so the render stage knows how many values to pop.
#[derive(Debug, Clone, PartialEq)]
pub struct Template {
    pub data: TemplateData,
    pub consumes_stack_entries: usize,
}
impl Template {
    pub fn substack(parsed: (Vec<TemplateValue>, usize)) -> Self {
        Self { data: TemplateData::Substack(parsed.0), consumes_stack_entries: parsed.1 }
    }
    pub fn list(parsed: (Vec<TemplateValue>, usize)) -> Self {
        Self { data: TemplateData::List(parsed.0), consumes_stack_entries: parsed.1 }
    }
    pub fn set(parsed: (Vec<TemplateValue>, usize)) -> Self {
        Self { data: TemplateData::Set(parsed.0), consumes_stack_entries: parsed.1 }
    }
    pub fn script(parsed: (Vec<TemplateValue>, usize)) -> Self {
        Self { data: TemplateData::Script(parsed.0), consumes_stack_entries: parsed.1 }
    }
}

/// The shape of a template literal.
#[derive(Debug, Clone, PartialEq)]
pub enum TemplateData {
    /// `(…)` — unordered concurrent substack
    Substack(Vec<TemplateValue>),
    /// `<…>` — sequentially-evaluated script
    Script(Vec<TemplateValue>),
    /// `[…]` — ordered list
    List(Vec<TemplateValue>),
    /// `{…}` without `:` — set
    Set(Vec<TemplateValue>),
    /// `{…}` with `:` — struct (key-value pairs)
    Struct(Vec<(TemplateValue, TemplateValue)>),
}

/// A single element inside a template literal.
#[derive(Debug, Clone, PartialEq)]
pub enum TemplateValue {
    /// `$n` — move the nth parent-stack entry into this position at render time.
    ParentStackMove(usize),
    /// `$name` — copy a label from the enclosing scope at render time.
    ParentLabel(String),
    /// A fully concrete program value requiring no substitution.
    Literal(ProgramValue),
}
impl From<RealValue> for TemplateValue {
    fn from(v: RealValue) -> Self { Self::Literal(v.into()) }
}
impl From<DataValue> for TemplateValue {
    fn from(v: DataValue) -> Self { Self::Literal(v.into()) }
}
impl From<ProgramValue> for TemplateValue {
    fn from(v: ProgramValue) -> Self { Self::Literal(v) }
}
impl From<Template> for TemplateValue {
    fn from(t: Template) -> Self { Self::Literal(t.into()) }
}
