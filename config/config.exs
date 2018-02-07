use Mix.Config

# lager is used by rabbit_common.
# Silent it by setting the higher loglevel.
config :lager,
  handlers: [level: :critical]
