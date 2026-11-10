"""Offline learning example. Run on a computer with Python 3; no dependencies."""
import json
from pathlib import Path

STORE = Path(__file__).with_name('supplies.json')


def load():
    if not STORE.exists():
        return {}
    data = json.loads(STORE.read_text(encoding='utf-8'))
    if not isinstance(data, dict) or not all(
        isinstance(k, str) and type(v) is int and v >= 0
        for k, v in data.items()
    ):
        raise ValueError('Expected names and non-negative integer counts')
    return data


def save(data):
    temporary = STORE.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(STORE)


def main():
    try:
        items = load()
    except (OSError, ValueError) as error:
        print('Cannot read inventory; preserve the existing file:', error)
        return
    while True:
        command = input('list / set / quit: ').strip().lower()
        if command == 'quit':
            return
        if command == 'list':
            for name, count in sorted(items.items()):
                print(f'{name}: {count}')
        elif command == 'set':
            name = input('Item name: ').strip()
            try:
                count = int(input('Count: '))
                if not name or count < 0:
                    raise ValueError('Name required; count must be non-negative')
                updated = {**items, name: count}
                save(updated)
                items = updated
            except (ValueError, OSError) as error:
                print('Not saved:', error)
        else:
            print('Choose list, set, or quit.')


if __name__ == '__main__':
    main()
