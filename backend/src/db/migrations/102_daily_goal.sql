-- Optional daily income goal of a driver (REA P3 #19, D82), in DH. NULL = no goal.
ALTER TABLE drivers ADD COLUMN daily_goal integer CHECK (daily_goal IS NULL OR daily_goal BETWEEN 10 AND 5000);
