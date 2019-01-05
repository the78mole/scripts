# Some ToDos for scripting repo

- Add a cronjob template to update this repo on a regular base
- Improve schedule_compile.sh
  * Maximum task count (over-limit processes will be suspended)
  * Calculate limit differently (first always runs, others suspended according their own mem amount, not the previous task)

