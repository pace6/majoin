"""Synapse module: notify the weather bot when a user registers.

Registers an account-validity `on_user_registration` callback. On every new
registration it POSTs `{"user_id": "..."}` to a webhook (the weather bot).

Install (on the homeserver):
  * place this file where Synapse's Python can import it, e.g.
      /opt/synapse/modules/majoin_register_hook.py
    and add that directory to PYTHONPATH, or `pip install` it as a package;
  * add to homeserver.yaml:

      modules:
        - module: majoin_register_hook.RegisterHook
          config:
            webhook_url: "http://127.0.0.1:8470/hooks/new-user"
            token: "change-me-too"   # must match the bot's HOOK_TOKEN

  * restart Synapse.
"""

import logging

from synapse.module_api import ModuleApi

logger = logging.getLogger(__name__)


class RegisterHook:
    def __init__(self, config: dict, api: ModuleApi):
        self._api = api
        self._url = config["webhook_url"]
        self._token = config.get("token", "")
        api.register_account_validity_callbacks(
            on_user_registration=self.on_user_registration,
        )
        logger.info("majoin_register_hook active -> %s", self._url)

    @staticmethod
    def parse_config(config: dict) -> dict:
        if "webhook_url" not in config:
            raise Exception("majoin_register_hook: 'webhook_url' is required")
        return config

    async def on_user_registration(self, user_id: str) -> None:
        headers = {}
        if self._token:
            headers["Authorization"] = ["Bearer " + self._token]
        try:
            await self._api.http_client.post_json_get_json(
                self._url, {"user_id": user_id}, headers
            )
            logger.info("notified weather bot of new user %s", user_id)
        except Exception as exc:  # noqa: BLE001 - never block registration
            logger.warning("register hook failed for %s: %s", user_id, exc)
