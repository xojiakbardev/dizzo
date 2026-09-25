from pydantic_settings import BaseSettings, SettingsConfigDict


class BotSettings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")
    telegram_bot_token: str = ""
    bot_token: str = ""
    bot_api_url: str = "http://localhost:8000/api"
    telegram_webapp_url: str = "http://localhost:3000"

    @property
    def token(self) -> str:
        return self.telegram_bot_token or self.bot_token


settings = BotSettings()
