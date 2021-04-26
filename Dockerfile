FROM busybox
ADD testfile.txt .
RUN rm testfile.txt && mkdir app && echo "hello" > /app/othertestfile.txt

