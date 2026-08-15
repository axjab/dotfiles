
# HOST CONFIGURATION

## FAST DEPLOYMENT

1. Clone this repo to `~/etc`
2. Run `cd ~/etc && hostcfg`

## EVENTS

2026 AUGUST 11

Named it the 'Hostfile'.

**2026 JULY 31** 

INVENTED A NEW DSL FOR CONFIGURATION INSPIRED BY THE DOCKERFILE. IT SHALL BE THE SOURCE OF TRUTH FOR
THE HOST'S ENVIRONEMENT CONFIGURATION.

## TODO

- [ ] NEED TO RECONCILE ALL BRANCHES (maybe just drop them)
- [ ] Write a script like alj.cx/<.sh> which clones and executes
- [ ] Add verbose option, show ALL directive outputs
		Default: show ONLY changes

 Add no-sync or fast option ()

 MAKE ALL PROCESS directive output READ-ONLY

 TODO: consolidate all branches

 NOTE: man, this shit is slowly turning into a bashrc. Perhaps it's tiem for some changes
 			in bashrc, check ~/env exists, if it exists, check if out of sync
 			if out of sync, prompt for sync followed by ~/env/rebuild
 			

 TODO: MOVE THIS PREAMBLE ELSEWHERE, THEN INTRODUCE RELOAD CONFIG

 TODO: PROCESS MUST ALWAYS CLEAN UP IF NO CHANGES SINCE LAST BACKUP

 TODO: PROMPT USER TO COMMIT A GIT REPO

