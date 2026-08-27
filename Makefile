.PHONY: test test-processor clean

test: test-processor

test-processor:
	$(MAKE) -C processor test

clean:
	$(MAKE) -C processor clean
