# monitoring/

Owner: Sasvat

Configuration for the monitoring stack that Compose runs in the `staging` profile (and in `dev` with the `monitoring` profile).

| Folder | What |
|---|---|
| `prometheus/` | Scrape config for the api, workers and exporters |
| `grafana/` | Provisioned data sources and five dashboards: API, Payments, Events, Infrastructure, Business (`grafana/dashboards/*.json`, in IST) |
| `METRICS.md` | The metric list every owner codes against |
