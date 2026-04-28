# Your Backstage, Your Problems, Your Metrics

Demos for the
talk [Your Backstage, Your Problems, Your Metrics](https://sessionize.com/s/ksick/your-backstage-your-problems-your-metrics/169505)
, by Thomas Schuetz & Katharina Sick.

## Structure

```
backstage/   Backstage instance used for all demos
```

## Problems & Demos

### Problem 1 — Service Creation

> When a developer wants to create a new service, they don't know where to start — they ask different people, get
> inconsistent answers, struggle to set up CI/CD themselves, and wait days for the ops team to unblock them.

**Backstage feature:** Software Templates  
**DevEx pillar:** Flow State

| Metric                                                                                                   | Type                 |
|----------------------------------------------------------------------------------------------------------|----------------------|
| % of new services created via templates, template completion rate, template error rate                   | Leading (Backstage)  |
| % of template runs completing the full Argo pipeline, time from template trigger to first deployment     | Leading (cross-tool) |
| Time from "I want a new service" to first commit, reduction in ops interruptions, developer satisfaction | Outcome              |

---

### Problem 2 — Working with Unfamiliar Services

> When a developer needs to work with an unfamiliar service — during an incident or picking up someone else's work —
> they have no single place to find who owns it, how it works, and what to do when it breaks.

**Backstage feature:** Service Catalog + TechDocs  
**DevEx pillar:** Cognitive Load

| Metric                                                                                      | Type                 |
|---------------------------------------------------------------------------------------------|----------------------|
| % of services with a defined owner, % with TechDocs coverage                                | Leading (Backstage)  |
| Doc freshness vs last commit date in GitHub, catalog ownership vs actual alerting routes    | Leading (cross-tool) |
| MTTR during incidents, reduction in "who owns this?" Slack messages, developer satisfaction | Outcome              |

---

### Problem 3 — Service Quality Visibility

> When a developer looks at a service — especially one that's been partially AI-generated — there's no way to know if
> it meets quality standards without manually checking five different places.

**Backstage feature:** Tech Insights / Scorecards  
**DevEx pillar:** Feedback Loops

| Metric                                                                                                           | Type                 |
|------------------------------------------------------------------------------------------------------------------|----------------------|
| % of services with a scorecard defined, average compliance score per team                                        | Leading (Backstage)  |
| Scorecard results vs external tools (Snyk, GitHub, Dynatrace), API spec vs actual production behavior            | Leading (cross-tool) |
| Reduction in ownerless service incidents, reduction in PR rejections due to standard violations, audit pass rate | Outcome              |
