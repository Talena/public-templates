echo "Arguments : $@" > /tmp/slave.log
echo `ls -l` >> /tmp/slave.log
./prepare-slave-node.sh $@
echo "Completed slave processing..." >> /tmp/slave.log
