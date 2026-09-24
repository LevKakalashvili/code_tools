# Только исходники
.\do_arch_service_folder.ps1

# Исходники и каталог .git
.\do_arch_service_folder.ps1 -IncludeGit

# Исходники и новый Git bundle
.\do_arch_service_folder.ps1 -IncludeGitBundle

# Включить одновременно .git и bundle
.\do_arch_service_folder.ps1 -IncludeGit -IncludeGitBundle
