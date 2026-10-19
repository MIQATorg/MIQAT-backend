-- name: UserExists :one
SELECT EXISTS(SELECT 1 FROM users WHERE username = $1);

-- name: IsAdminStored :one
SELECT EXISTS(SELECT 1 FROM users WHERE role = 'admin');

-- name: GetUserForLogin :one
SELECT id, username, display_name, password_hash, role
FROM users
WHERE username = $1;

-- name: GetUserByID :one
SELECT id, username, display_name, role
FROM users
WHERE id = $1;

-- name: RegisterUser :one
INSERT INTO users (username,display_name,password_hash,role) VALUES ($1,$2,$3,$4)
RETURNING *;

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
-- name: GetSessionByTokenHash :one
SELECT id, user_id, user_agent, kind, platform, expires_at
FROM login_sessions
WHERE token_hash = $1
  AND expires_at > NOW();

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

-- name: RevokeSessionById :exec
DELETE FROM login_sessions where id=$1 AND user_id=$2;

-- name: RevokeSessionByToken :exec
DELETE FROM login_sessions where token_hash=$1;

-- name: RevokeAllUserSessions :exec
DELETE FROM login_sessions where user_id=$1;

-- name: RevokeUserSessionByUserAgent :exec
DELETE FROM login_sessions where user_id=$1 AND user_agent=$2;



