.PHONY: check serve

check:
	python3 -m compileall -q speech_server
	python3 -m unittest discover -s speech_server -t . -p 'test_*.py' -v

serve:
	python3 -m speech_server
