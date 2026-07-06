# Model Routing

Use cheaper and local models first. Escalate only when confidence is low or risk is high.

| Work type | Model class |
|---|---|
| File search | local or small |
| Summaries | local or small |
| Boilerplate | local or small |
| Test generation | medium |
| CI log review | medium |
| Bug diagnosis | medium or strong |
| Architecture | strong |
| Final acceptance | strong |

Rule:

```text
cheap first -> verify -> escalate only when needed
```
