---
name: frontend-design-workflow
description: Mandatory end-to-end frontend design and development workflow. Use whenever building, designing, redesigning, or modifying web pages, dashboards, landing pages, application UI, or major components. Orchestrates design read, intelligence, design system persistence, craft review, and runtime browser verification.
user-invocable: true
---

# Frontend Design Workflow

This is an orchestration skill. It establishes a mandatory 6-phase pipeline ensuring that frontend applications and UI components achieve high aesthetic standards, consistent design tokens, total accessibility, and verified runtime behavior.

Do not replace, summarize, or skip the referenced skills. Invoke and follow each skill in the required sequence. The output of each phase must feed directly into the next phase.

---

## The 6-Phase Pipeline

```
Phase 1: Design Read (design-taste-frontend)
  ↓
Phase 2: Design Intelligence & Brand Reference (meoo-design-kungfu)
  ↓
Phase 3: Design System Persistence (ui-ux-pro-max)
  ↓
Phase 4: Implementation (Code against persisted tokens)
  ↓
Phase 5: Craft & Quality Review (impeccable)
  ↓
Phase 6: Runtime Browser Verification (Playwright / DevTools)
  ↓
Completion Gate
```

---

## Phase 1 — Design Read & Anti-Slop (design-taste-frontend)

Before writing any frontend code or choosing templates:

1. **Invoke `design-taste-frontend`**.
2. **Execute Brief Inference & Output Design Read**:
   State in one line before doing anything else:
   `"Reading this as: <page kind> for <audience>, with a <vibe> language, mode=<Operate|Persuade|Read|Experience>."`
3. **Establish Constraints & Baseline Dials**:
   - `DESIGN_VARIANCE` (1–10)
   - `MOTION_INTENSITY` (1–10)
   - `VISUAL_DENSITY` (1–10)
4. **Identify the Single Visual Anchor**:
   Determine the one memorable, subject-grounded visual element or interaction. Cut generic decoration.
5. **Anti-Slop Enforcement**:
   Explicitly ban AI default clichés:
   - No generic purple/blue gradients or dark mesh backgrounds.
   - No 3-equal-card SaaS clichés with identical soft shadows.
   - No unconsidered Inter or system font defaults.
   - No tracked-out ALL-CAPS eyebrow labels above every header.

*Halt rule: Do not begin implementation or token generation until Phase 1 Design Read is explicitly declared.*

---

## Phase 2 — Design Intelligence & Brand DNA (meoo-design-kungfu)

Ground the aesthetic direction in proven, real-world design systems:

1. **Invoke `meoo-design-kungfu`**.
2. **Match Industry & Brand Archetypes**:
   - Consult `meoo-design-kungfu`'s catalog (140+ styles, 53 benchmark brands).
   - Examples:
     - Developer tools / dense dashboards → Linear / Raycast / Supabase style.
     - Enterprise B2B / Financial → Stripe / Resend / Carbon style.
     - Consumer / Creative → Apple / Framer / Vercel style.
3. **Extract Component & Layout Recipes**:
   Borrow concrete component patterns (buttons, cards, inputs, navigation) and CSS/Tailwind recipes suited for the chosen stack.

*Do not copy arbitrary visual styles without business and audience justification.*

---

## Phase 3 — Design System & Token Persistence (ui-ux-pro-max)

Translate the aesthetic decisions into a strict, reproducible design system:

1. **Invoke `ui-ux-pro-max`**.
2. **Run Design System CLI**:
   Execute the search script to generate the design system tokens:
   ```bash
   python "/Users/suxiaoxing/.gemini/config/skills/ui-ux-pro-max/scripts/search.py" \
     "<product_type> <industry> <keywords>" \
     --design-system \
     --variance <1-10> --motion <1-10> --density <1-10> \
     --persist --output-dir "<project-root>"
   ```
3. **Verify Persisted Artifacts**:
   Ensure `design-system/MASTER.md` or `DESIGN.md` exists in the project root before writing code.
4. **Freeze Tokens**:
   Establish exact tokens for:
   - Palette (Primary, surface, border, muted, accent)
   - Typography (Font family, scale ratio, line heights)
   - Spacing & Radius scale (Density-aligned)
   - Motion presets (Timing, easing, GSAP/Framer motion configs)

*Halt rule: Do not write implementation code until design tokens are persisted on disk.*

---

## Phase 4 — Implementation

Implement the application, pages, or components strictly following the frozen tokens:

1. **Token Compliance**:
   - Use only established CSS variables, Tailwind classes, or design tokens from Phase 3.
   - Never inject arbitrary hex colors (e.g. `#1a1a2e`) or random margins/padding outside the design system scale.
2. **Component Architecture**:
   - Implement real copy and domain-accurate terminology; avoid filler text or generic copy.
   - Build accessible primitives with clear semantic HTML and ARIA labels.
   - Ensure touch targets meet minimum 44×44px standards.

---

## Phase 5 — Craft Review & Hardening (impeccable)

Inspect and refine the implemented UI against design director standards:

1. **Invoke `impeccable`**.
2. **Quality & Surface Evaluation**:
   - Check against `craft-floor.md` for absolute quality floor and banned anti-patterns.
   - Run `impeccable audit` for accessibility, contrast (minimum 4.5:1), responsive layout, and dark/light mode balance.
3. **Intentional Calibration**:
   - If UI feels bland or tentative → run `impeccable bolder`.
   - If UI feels chaotic or noisy → run `impeccable quieter` or `distill`.
   - Before shipping → run `impeccable harden` for edge cases, error states, loading skeletons, and empty states.
4. **Resolution Rule**:
   Every material finding surfaced during review must either be resolved in code or explicitly justified in the report.

---

## Phase 6 — Runtime Verification

Verify the actual rendered UI in a live browser environment before declaring completion:

1. **Launch & Connect**:
   - Start local dev server if needed and connect via Playwright or Chrome DevTools.
2. **Check Multiple Viewports**:
   - Desktop (1440px / 1280px)
   - Tablet (768px)
   - Mobile (375px / 390px)
3. **Verify Interactive Behavior**:
   - No horizontal scrollbars or overflow clipping.
   - Focus rings visible during keyboard navigation (Tab/Shift+Tab).
   - Hover, active, focus, and disabled states respond cleanly.
   - Test empty, loading, error, and dynamic content states.
4. **Console & Performance Audit**:
   - Verify zero unhandled browser console errors or layout shift warnings.

---

## Completion Gate

Never declare completion unless all 6 phases have been systematically executed.

In your final report to the user, include:
- **Skills Invoked**: Confirmation of execution for each required skill.
- **Design Read Summary**: Audience, product kind, mode, and chosen aesthetic direction.
- **Design System Artifact**: Path to the generated `MASTER.md` or `DESIGN.md`.
- **Craft & Audit Outcomes**: Issues identified by `impeccable` and how they were resolved.
- **Runtime Verification Evidence**: Screenshots, viewport tests passed, and console error status.
