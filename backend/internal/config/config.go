package config

import (
	"fmt"
	"log/slog"
	"os"

	"github.com/go-playground/validator/v10"
	"github.com/knadh/koanf/parsers/dotenv"
	"github.com/knadh/koanf/parsers/yaml"
	"github.com/knadh/koanf/providers/file"
	"github.com/knadh/koanf/v2"
)

type Config struct {
	Primary  Primary        `koanf:"primary" validate:"required"`
	Server   ServerConfig   `koanf:"server" validate:"required"`
	Database DatabaseConfig `koanf:"database" validate:"required"`
	Logging  LoggingConfig  `koanf:"logging" validate:"required"`
}

type Primary struct {
	Env    string `koanf:"env" validate:"required"`
	Domain string `koanf:"domain" validate:"required"`
}

type ServerConfig struct {
	Host               string   `koanf:"host" validate:"required"`
	Port               string   `koanf:"port" validate:"required"`
	ReadTimeout        int64    `koanf:"read_timeout" validate:"required"`
	WriteTimeout       int64    `koanf:"write_timeout" validate:"required"`
	IdleTimeout        int64    `koanf:"idle_timeout" validate:"required"`
	CORSAllowedOrigins []string `koanf:"cors_allowed_origins" validate:"required"`
	SESSION_KEY        *string
}

func (s ServerConfig) GetAddr() string {
	return fmt.Sprintf("%s:%s", s.Host, s.Port)
}

type DatabaseConfig struct {
	Host            string `koanf:"host" validate:"required"`
	Port            int    `koanf:"port" validate:"required"`
	User            string `koanf:"user" validate:"required"`
	Password        string `koanf:"password"`
	Name            string `koanf:"name" validate:"required"`
	SSLMode         string `koanf:"ssl_mode" validate:"required"`
	MaxOpenConns    int    `koanf:"max_open_conns" validate:"required"`
	MaxIdleConns    int    `koanf:"max_idle_conns" validate:"required"`
	ConnMaxLifetime int    `koanf:"conn_max_lifetime" validate:"required"`
	ConnMaxIdleTime int    `koanf:"conn_max_idle_time" validate:"required"`
}

func (d DatabaseConfig) GetConnString() string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		d.User,
		d.Password,
		d.Host,
		d.Port,
		d.Name,
		d.SSLMode,
	)
}

type LoggingConfig struct {
	Level  string `koanf:"level" validate:"required"`
	Format string `koanf:"format" validate:"required"`
}

func LoadConfig() *Config {
	k := koanf.New(".")
	if err := k.Load(file.Provider("config.yaml"), yaml.Parser()); err != nil {
		slog.Error("error loading config:", "error", err)
		os.Exit(1)
	}

	var config Config
	err := k.Unmarshal("", &config)
	if err != nil {
		slog.Error("could not unmarshal main config")
		os.Exit(1)
	}

	validate := validator.New()

	err = validate.Struct(config)
	if err != nil {
		slog.Error("config validation failed")
		os.Exit(1)
	}

	if err := k.Load(file.Provider(".env"), dotenv.Parser()); err != nil {
		slog.Error("Error loading .env file: %v", err)
		os.Exit(1)
	}

	// Retrieve a string variable
	SESSION_KEY := k.String("SESSION_KEY")
	if SESSION_KEY == "" {
		slog.Error("Error reading SESSION_KEY env variable: %v", err)
		os.Exit(1)

	}
	config.Server.SESSION_KEY = &SESSION_KEY

	return &config
}

func (c Config) GetLogLevel() string {
	switch c.Primary.Env {
	case "production":
		if c.Logging.Level == "" {
			c.Logging.Level = "info"
			return "info"
		}
	case "development":
		if c.Logging.Level == "" {
			c.Logging.Level = "debug"
			return "debug"
		}
	}
	return c.Logging.Level
}

func (c *Config) IsProduction() bool {
	return c.Primary.Env == "production"
}
