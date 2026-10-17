package config

import (
	"log/slog"
	"os"

	"github.com/go-playground/validator/v10"
	"github.com/knadh/koanf/parsers/yaml"
	"github.com/knadh/koanf/providers/file"
	"github.com/knadh/koanf/v2"
)

type Config struct {
    Primary  Primary `koanf:"primary" validate:"required"`
    Server   ServerConfig   `koanf:"server" validate:"required"`
    Database DatabaseConfig `koanf:"database" validate:"required"`
    Logging  LoggingConfig    `koanf:"logging" validate:"required"`
    Auth     AuthConfig `koanf:"auth" validate:"required"` 
}

type Primary struct{
    Env string `koanf:"env" validate:"required"`
}

type ServerConfig struct{
    Port string `koanf:"port" validate:"required"`
    ReadTimeout int `koanf:"read_timeout" validate:"required"`
    WriteTimeout int `koanf:"write_timeout" validate:"required"`
    IdleTimeout int `koanf:"idle_timeout" validate:"required"`
    CORSAllowedOrigins []string `koanf:"cors_allowed_origins" validate:"required"`
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

type AuthConfig struct {
	SecretKey string `koanf:"secret_key" validate:"required"`
}


type LoggingConfig struct {
	Level              string        `koanf:"level" validate:"required"`
}


func loadConfig() (*Config, error){ 
    var k = koanf.New(".")
    if err := k.Load(file.Provider("config.yaml"), yaml.Parser()); err != nil {
		slog.Error("error loading config: %v", err)
        os.Exit(1)
	}

    var config Config
    err := k.Unmarshal("", &config)
    if err != nil{ 
        slog.Error("could not unmarshal main config") 
        os.Exit(1)
    }

    validate := validator.New()

	err = validate.Struct(config)
	if err != nil {
        slog.Error("config validation failed")
        os.Exit(1)
	}

    return &config,nil

}

func (c Config) GetLogLevel() (string){
    switch c.Primary.Env{
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
