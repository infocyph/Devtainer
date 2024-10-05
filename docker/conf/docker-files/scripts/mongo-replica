#!/bin/bash

# Wait for the MongoDB server to be fully up and running
sleep 10

echo "Initiating Replica Set..."
mongo --eval 'rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "mongo-primary:27017" },
    { _id: 1, host: "mongo-secondary1:27017" },
    { _id: 2, host: "mongo-secondary2:27017" }
  ]
})'
