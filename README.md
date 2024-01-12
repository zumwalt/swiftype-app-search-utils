# Swiftype App Search engine utils

Pull configuration from a Swiftype App Search engine

## Installation

```bash
bundle install
```

## Configuration

Copy `.env.example` to `.env` and fill in the values:

```bash
cp .env.example .env
```

This script requires the following environment variables to be set in `.env`:

```bash
HOST_IDENTIFIER='<host_identifier>'
PRIVATE_API_KEY='<private_api_key>'
ENGINE_NAME='<engine_name>'
```

Optional environment variables:

```bash
URL_FIELD='<url_field>' # defaults to 'url'
```

## Usage

```bash
bundle exec ruby main.rb
```

## Output

The script will output two files:

- `synonyms.json`: contains all synonyms from the engine
- `curations.json`: contains all curations from the engine
