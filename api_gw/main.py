from flask import Flask

app = Flask(__name__)

@app.route('/', methods=['GET'])
def hello():
    return "hello from docker"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8500)