SELECT
    user_id,
    sum(clicks)
FROM sessions
GROUP BY user_id
HAVING (argMax(clicks, created_at) = 16) AND (argMax(platform, created_at) = 'Rat')
FORMAT `Null`
