# Gets latest image tag
# docker images localhost:5000/python-web-app:latest

# get latest tag / release from git
# git describe --tags

# Gets all images and sorts based on date, use head to show just the latest.
docker images localhost:5000/python-web-app --format "{{.Repository}} || {{.Tag }} || {{.ID}} || {{.CreatedAt}}" | sort -r | head -n1

