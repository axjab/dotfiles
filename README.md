
# HOST KINDLING

## TODO

**Move these to the Hosts of Embers project.**

- [ ] SERVE hosts.alj.cx which contains LIVE data of my host based on the Beszel model
- [ ] Rename this branch "master", delete all others
- [ ] (firekeeper) During initializion, create a "Host daemon" which monitors the health
			of its host, using a host "doctor" and notifies of drifting based on hosts.alj.cx
- [ ] REPLACE Hostfile with solutions from https://github.com/axjab/hosts-of-embers.
			Make sure long tasks are run CONCURRENTLY.

## INITIALIZATION

1. Initialize:

```bash
curl -fsSL https://raw.githubusercontent.com/axjab/etc/server/kindle.sh | bash
```

Future version:

```bash
	curl -fsSL https://hosts.alj.cx/kindle.sh | bash
```

2. If step 1 worked: `git clone github:axjab/etc` (embed in kindle.sh?)
3. Run `hostcfg` (sets up symlinks). Replace with `embers` command eventually.

## EVENTS

2026 OCTOBER 13

Hosts of embers project is born, designed to take over host provisioning and orchestration
instead of weak Hostfile solution.

2026 AUGUST 11

Named it the 'Hostfile'.

**2026 JULY 31** 

INVENTED A NEW DSL FOR CONFIGURATION INSPIRED BY THE DOCKERFILE. IT SHALL BE THE SOURCE OF TRUTH FOR
THE HOST'S ENVIRONEMENT CONFIGURATION.
