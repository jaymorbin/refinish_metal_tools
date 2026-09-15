# Index generators

Regenerates the three repo `INDEX.md` files by parsing the repos. Run after adding
files to any of them, so the indexes do not go stale.

Clone all three to the same parent directory, then from that directory:

```bash
python3 analyze.py    # extract raw signals   -> extract.json
python3 classify.py   # classify + topic-tag  -> extract.json
python3 genindex.py   # writes data + raws indexes
python3 gentools.py   # writes tools index
```

Paths at the top of `analyze.py` assume the repos are at `/df_data_reference`,
`/vanilla_raws_reference` and `/refinish_metal_tools`. Edit those if they sit
elsewhere. Output goes to `/mnt/user-data/outputs`.

Nothing here reads the live game or the RM project. It only parses the repos.
