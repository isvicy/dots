# ZSH 首次启动时找不到命令问题

## 问题现象

首次打开终端时出现以下错误：

```
fzf missing!
atuin missing!
direnv missing!
```

执行 `exec zsh` 后一切正常。

同时 `zsh-autosuggestions` 在首次启动时不工作，`kimi-cli` 插件报错：

```
No such widget `.__kimi_cli_prev_backward_delete_char'
```

## 根本原因

### 问题一：Homebrew PATH 设置太晚

在 `~/.zsh-custom/thirdparty.zsh` 中，Homebrew 的 PATH 设置（`brew shellenv`）位于文件末尾，
但 `fzf`、`atuin`、`direnv` 的检查在文件开头。

加载顺序：
1. 检查 `fzf` → Homebrew PATH 还没加入 → 找不到 → 报错
2. 最后执行 `brew shellenv` 把 `/opt/homebrew/bin` 加到 PATH
3. `exec zsh` 重新启动 → PATH 已正确 → 能找到

### 问题二：zinit 延迟加载导致插件未就绪

`.zshrc` 中使用了 `wait lucid` 延迟加载 `zsh-autosuggestions` 和 `zsh-kimi-cli`：

```zsh
zinit ice wait lucid
zinit light zsh-users/zsh-autosuggestions

zinit ice wait lucid
zinit light MoonshotAI/zsh-kimi-cli
```

`wait` 意味着等 prompt 显示后再异步加载，导致首次打开终端时插件还没准备好。

`kimi-cli` 的 widget 报错是因为它在加载时会注册 `backward-delete-char` 等 widget 的别名，
但延迟加载时 zle 环境还不完整，`zle -A` 失败。

## 解决方案

### 修复一：把 Homebrew 加载移到 thirdparty.zsh 开头

```zsh
# Homebrew must be loaded first before other tools
[[ -s /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)" || true

# 然后才是其他工具的检查...
if command -v fzf >/dev/null 2>&1; then
    ...
fi
```

### 修复二：调整 zinit 插件加载策略

1. `zsh-autosuggestions` 改为立即加载（它很轻量）：

```zsh
zinit light zsh-users/zsh-autosuggestions
```

2. `zsh-kimi-cli` 使用 `wait"0"` 在 zle 初始化后立即加载：

```zsh
zinit ice wait"0" lucid
zinit light MoonshotAI/zsh-kimi-cli
```

`wait"0"` 表示在 prompt 显示后 0 毫秒延迟加载，此时 zle 已完全初始化。

## 相关文件

- `~/.zshrc`
- `~/.zsh-custom/thirdparty.zsh`
- `~/.zsh-custom/init.zsh`

## 参考

- zinit turbo mode: https://github.com/zdharma-continuum/zinit#turbo-and-lucid
