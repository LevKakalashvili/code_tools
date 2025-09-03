CHANGED_PY_FILES = $(shell git diff --name-only --diff-filter=ACM HEAD | findstr /R "\.py")

format_and_check_code_changed_win:
	@for %%f in ($(CHANGED_PY_FILES)) do (\
 		isort %%f && \
 		black %%f && \
		autoflake %%f && \
 		pflake8 %%f\
 	)
