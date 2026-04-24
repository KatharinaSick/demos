# Your Backstage, Your Problems, Your Metrics

Demos for the
talk [Your Backstage, Your Problems, Your Metrics](https://sessionize.com/s/ksick/your-backstage-your-problems-your-metrics/169505).

## File structure

```
backstage // contains the Backstage instance we're using for the demo

```

## Problems to demo

Bei den metrics habe ich immer 2 Kategorien angegeben:
Leading: Was wir in unserer Platform messen können:
Backstage: was wir nur mit Backstage messen können
cross-tool: was wir über mehrere tools in der platform messen können (zb Backstage + Argo Workflows für software
templates)
Outcome: Was sich tatsächlich in der org verändert

Problem 1
When a developer wants to create a new service, they don't know where to start — they ask different people/agents, get
inconsistent answers, struggle to set up CI/CD themselves, and wait days for the ops team to unblock them. All before
they've written a single line of business logic.
Backstage Feature: Software Templates
DevEx Pillar: Cognitive Load & Flow State
Metrics:
Leading (in Backstage): % of new services created via templates, template completion rate, template error rate
Leading (cross-tool): % of template runs that successfully complete the full pipeline in Argo, time from template
trigger to first successful deployment
Outcome (external): Time from "I want a new service" to first commit, reduction in ops team interruptions for service
setup, developer satisfaction score for onboarding new services
---
Problem 2
When a developer needs to work with an unfamiliar service — whether during an incident or picking up someone else's
work — they have no single place to find who owns it, how it works, and what to do when it breaks.
Backstage Feature: Service Catalog + TechDocs
DevEx Pillar: Cognitive Load + Flow State
Metrics:
Leading (in Backstage): % of services with a defined owner in the catalog, % of services with TechDocs coverage, % of
services with a certain techdocs page
Leading (cross-tool): Doc freshness score vs last commit date in GitHub, catalog ownership vs actual alerting routes
Outcome (external): Mean time to resolution (MTTR) during incidents, reduction in "who owns this?" Slack messages,
developer satisfaction score for working with unfamiliar services
---
Problem 3
When a developer looks at a service — especially one that's been partially AI-generated — there's no way to know if it
meets quality standards around documentation, ownership, tech stack compliance, and API contracts without manually
checking five different places.
Backstage Feature: Scorecards / Tech Insights Plugin
DevEx Pillar: Cognitive Load + Feedback Loops
Metrics:
Leading (in Backstage): % of services with a scorecard defined, average scorecard compliance score per team
Leading (cross-tool): Scorecard results vs actual state in external tools (e.g. Snyk for security, GitHub for doc
freshness, Dynatrace for service health), API spec in Backstage vs actual API behavior observed in production
Outcome (external): Reduction in "this service has no owner" incidents, reduction in PR rejections due to standard
violations, improvement in audit pass rate