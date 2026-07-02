# Provisioning — PUC2-Sub Case 2a

The playbooks and roles in this directory deploy the infrastructure required by the
Phishing Attack Training Scenario on CyberRangeCZ.

## Host groups

| Inventory group | Hosts | Purpose |
|----------------|-------|---------|
| `rep_core` | `rep-scheduler`, `rep-live-session`, `rep-quiz-engine`, `rep-practical-labs` | REP backend microservices (nginx reverse proxy per node) |
| `lms_content` | `rep-practical-labs` | LMS course portal — Nginx virtual host on port 8080 |
| `phishing_simulator` | `phishing-simulator` | GoPhish phishing simulation platform (Docker) |
| `mail_relay` | `mail-relay` | MailHog sandboxed SMTP relay (Docker) |
| `reporting_workspace` | `reporting-workspace` | Grafana dashboards + PostgreSQL |
| `instructor_console` | `instructor-console` | Instructor terminal with tmux and browser shortcuts |
| `trainees` | `trainee-workstation-01`, `trainee-workstation-02` | Windows 10 workstations with REP Collector agent |

## Requirements

- Ansible 2.15 or newer
- `pywinrm` Python package for WinRM connectivity to Windows hosts
  (`pip install "pywinrm[credssp]"` when CredSSP is required)
- Network reachability to all hosts in `provisioning/case-2a/topology.yml`
- Credentials via Ansible Vault or environment variables (see `inventory.sample`)

> **KYPO/CRCZ note:** always use `provisioning/run_playbook.sh` rather than calling
> `ansible-playbook` directly; the wrapper installs required collections first.

## Running the playbook

```bash
# 1. Export credentials or prepare an Ansible Vault file
export ANSIBLE_PASSWORD_PHISHING_SIMULATOR='...'

# 2. Copy and adjust the inventory
cp inventory.sample inventory.ini

# 3. Run
provisioning/run_playbook.sh inventory.ini
```

## Role reference

### `rep-core`
Installs Nginx as a reverse proxy for each REP backend microservice. Key variables:
`rep_core_tls_enabled`, `rep_core_virtual_host`, `rep_core_shared_secret`.
TLS is disabled by default for lab environments.

### `lms-content`
Adds a second Nginx virtual host (port 8080) on `rep-practical-labs` serving the
self-paced phishing awareness course. The web root is `/srv/lms/`. Update course
content by editing files there directly or re-running the role.

### `phishing-simulator`
Deploys GoPhish via Docker Compose on the `phishing-simulator` host.
- Admin panel: `http://phishing-simulator.internal:3333/`
- Phishing pages: `http://phishing-simulator.internal/`
- Pre-configures the MailHog SMTP sending profile on first run.
- Initial admin credentials are saved to `/opt/phishing-simulator/admin_credentials.txt`.

Key variables: `phishing_simulator_admin_port`, `phishing_simulator_phishing_port`,
`phishing_simulator_smtp_host`, `phishing_simulator_from_address`.

### `mail-relay`
Deploys MailHog via Docker Compose on the `mail-relay` host.
- SMTP: port 1025 (used by GoPhish as outbound relay)
- WebUI: `http://mail-relay.internal:8025/` (trainee inbox)

All emails stay inside the sandbox — nothing reaches the internet.

### `reporting-workspace`
Installs PostgreSQL and Grafana on `reporting-workspace`.
- Grafana dashboard: `http://reporting.internal:3000/`
- PostgreSQL database `rep_reporting` is created automatically.

Key variables: `reporting_workspace_datasources`, `reporting_workspace_dashboards`.

### `instructor-console`
Configures the instructor's Ubuntu workstation with tmux sessions and shell
shortcuts. Default shortcuts open GoPhish, MailHog, the LMS portal, and Grafana.
Key variables: `instructor_console_shortcuts`, `instructor_console_tmux_settings`.

### `trainee-workstation`
Deploys the REP Collector agent (PowerShell service) and a welcome note on each
Windows workstation. Key variables: `trainee_workstation_collector.*`,
`trainee_workstation_welcome_note`.

### `windows`
Basic Windows OS hardening: disables automatic updates, enables RDP and WinRM,
adjusts firewall rules. Always applied before `trainee-workstation`.

## Helper scripts

| Script | Purpose |
|--------|---------|
| `case-2a/scripts/export_gophish_results.sh` | Export campaign results via GoPhish REST API to JSON |
| `case-2a/scripts/examples/campaign-config.json` | Example GoPhish campaign payload |

## Parameterisation

All roles expose defaults in `roles/<role>/defaults/main.yml`. Override them in
`group_vars/`, `host_vars/`, or with `-e` on the command line without editing templates.
