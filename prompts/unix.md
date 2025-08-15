# Unix Philosophy Quick Reference

## Core Question
**"Is this the smallest, most focused solution?"**

## Principles

**1. Do One Thing Well**
- Single responsibility per module/function
- Check: Can this split without losing cohesion?

**2. Work Together**
- Loose coupling via clean interfaces
- Standard data formats between modules
- Check: Does this plug in easily?

**3. Text as Interface**
- JSON/CSV/structured logs for exchange
- Human-readable configs
- Check: Avoiding proprietary formats?

**4. Keep It Simple**
- Simple over clever solutions
- Leverage framework conventions
- Check: Simpler alternative exists?

**5. Rule of Silence**
- Quiet success, verbose failures
- Minimal prod logs, detailed dev feedback
- Check: Creating log noise?

**6. Rule of Repair**
- Fail fast with actionable errors
- Early validation at boundaries
- Check: Failures guide fixes?

**7. Rule of Economy**
- Optimize for developer time
- Readable, reusable code
- Check: Saves dev/maintenance time?

## Quick Checks
- [ ] Single clear purpose per module?
- [ ] Components easily swappable?
- [ ] Data formats tool-friendly?
- [ ] Simplest working solution?
- [ ] Quiet success, clear failures?
- [ ] Errors help debugging?
- [ ] Optimized for dev productivity?

## Red Flags
- Over-engineering simple features
- Analysis paralysis over shipping
- Complex patterns when simple works
