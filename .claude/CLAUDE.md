# General Guidelines

- **Tools**: Use rg not grep, fd not find, tree is installed
- **Style**: Prefer self-documenting code over comments, and as of comments, you
  should make sure it's necessary for senior developers, don't add comments for
  obvious things.

---

# Anki 卡片创建指南

这是生成 anki flashcard 时需要遵循的约定。

## 核心原则

- 每个问题的答案除了答案本身之外，还需要有对应的解释，以帮助理解答案的来源和背景；这样一个卡片本身是自解释的
- 如果有代码示例，请使用代码块进行包裹

## 安全规则

**永远不要自动执行删除 Deck 的操作。** 重命名 deck、清理 deck 等涉及删除的操作必须由用户在 Anki 中手动完成。

## 创建流程

**重要：在执行实际创建之前，必须先展示待创建的卡片设计内容，获得用户同意后再执行创建。**

## 批量创建

使用 `create_notes_bulk` 可以一次创建多个卡片：
- 支持混合不同的卡片类型
- 自动处理重复检测
- 可选的自动音频生成（适用于语言学习）

## 推荐使用的卡片类型

### 1. Better Markdown : Basic

- **特点**：支持 Markdown 语法、代码高亮、LaTeX 公式
- **适用场景**：普通问答题、概念解释、代码示例
- **字段**：Front, Back, Extra, Difficulty

### 2. Quizify - 格致 (@chehil)

- **特点**：支持填空题和选择题，在没有使用自定义填空或者选择题语法时，支持 Markdown 语法；当使用自定义语法时，仅支持代码块高亮;
- **适用场景**：需要互动的学习内容
- **字段**：Front, Back, Add Reverse
- **格式要求**：
  - 填空题：使用 `{{内容}}`
  - 选择题：Front 必须以 `[` 开头，以 `]::(答案)` 结尾
    - 单选题答案：单个字母，如 `::(B)`
    - 多选题答案：多个字母，如 `::(ABC)`

## 卡片样例

### Better Markdown : Basic - 带代码示例

**Front:**
```
Go 语言中的 io.Reader 接口定义是什么？
```

**Back:**
````markdown
```go
type Reader interface {
    Read(p []byte) (n int, err error)
}
```

**解释：**
- Read 方法从数据源读取数据到字节切片 p 中
- 返回读取的字节数 n 和可能的错误 err
- 当读取到数据末尾时，返回 `io.EOF` 错误
````

### Quizify - 填空题

**Front:**
```
bufio.NewReader 创建一个带缓冲的 Reader，默认缓冲区大小是 {{4096}} 字节。
```

**Back:** （留空）

### Quizify - 选择题

**Front:**
```
[当 io.Reader 的 Read 方法返回 n > 0 且 err != nil 时，正确的处理方式是？<br>A. 立即返回错误<br>B. 先处理数据再处理错误<br>C. panic<br>D. 重试]::(B)
```

**Back:**
```
((选项 A::不正确。已读取的数据仍然有效。))<br>((选项 B::✓ 正确！应先处理 n 个字节的有效数据，再处理错误。))<br>((选项 C::不正确。这是正常行为。))<br>((选项 D::不正确。应先处理已读取的数据。))
```

## 快速检查清单

1. ✅ 先展示设计，获得用户同意后再创建
2. ✅ 优先使用 Better Markdown : Basic 或 Quizify
3. ✅ 每个答案都要包含解释
4. ✅ 代码要用代码块包裹
5. ✅ Quizify 选择题必须以 `[` 开头，以 `]::(答案)` 结尾
