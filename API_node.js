const express = require('express');
const app = express();
const PORT = 3000;

// This endpoint replies "Hello" when you access the root URL
app.get('/', (req, res) => {
    res.send('Hello');
});

// Start the server
app.listen(PORT, () => {
    console.log(`Server is running at http://localhost:${PORT}`);
});
