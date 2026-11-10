"""Print content fingerprints for reviewers. This command does NOT approve content."""
import argparse
import json
from pathlib import Path
from check import review_digest

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file",type=Path)
    args=parser.parse_args()
    data=json.loads(args.file.read_text())
    articles=data["articles"] if isinstance(data,dict) else data
    for article in articles:
        print(f"{article['id']}/{article['language']} {review_digest(article)}")
