-- name: IsUserExistsById :one
SELECT EXISTS(SELECT 1 FROM users WHERE id = $1);

-- name: IsUserExistsByUsername :one
SELECT EXISTS(SELECT 1 FROM users WHERE username = $1);


-- name: IsAdminStored :one
SELECT EXISTS(SELECT 1 FROM users WHERE role = 'admin');

-- name: GetUserForLogin :one
SELECT *
FROM users
WHERE username = $1;

-- name: GetUserByID :one
SELECT * 
FROM users
WHERE id = $1;

-- name: RegisterUser :one
INSERT INTO users (username,display_name,password_hash,role) VALUES ($1,$2,$3,$4)
RETURNING *;


-- name: GetUserRoleById :one
SELECT role from users where id = $1;

-- name: CreateSession :one
INSERT INTO login_sessions (
    user_agent,
    user_id,
    kind,
    token_hash,
    platform,
    expires_at
)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;


-- name: CreateUserSettings :exec
INSERT INTO user_settings(user_id,timezone) VALUES($1,$2);

-- name: GetUserBySessionTokenHash :one
SELECT * FROM users where id = (SELECT user_id FROM login_sessions where token_hash = $1 AND revoked_at IS NULL and expires_at > NOW());

-- name: GetSessionByTokenHash :one
SELECT *
FROM login_sessions
WHERE token_hash = $1
  AND expires_at > NOW() AND revoked_at IS NULL;

-- name: ListUserSessions :many
SELECT id, user_agent, kind, platform, expires_at
FROM login_sessions
WHERE user_id = $1
  AND expires_at > NOW()
ORDER BY expires_at DESC;

-- name: deleteUserById :exec
DELETE FROM users where id=$1;

-- name: DeleteUserByUsername :exec
DELETE FROM users where username=$1;

-- name: RevokeSessionById :one
UPDATE login_sessions
SET revoked_at = NOW()
WHERE id = $1 AND user_id = $2 AND revoked_at IS NULL
RETURNING *;

-- name: RevokeSessionByToken :one
UPDATE login_sessions
SET revoked_at = NOW()
WHERE token_hash = $1 AND revoked_at IS NULL
RETURNING *;

-- name: RevokeAllUserSessions :exec
UPDATE login_sessions
SET revoked_at = NOW()
WHERE user_id = $1 AND revoked_at IS NULL;

-- name: RevokeUserSessionByUserAgent :exec
UPDATE login_sessions
SET revoked_at = NOW()
WHERE user_id = $1
  AND user_agent = $2
  AND revoked_at IS NULL;
