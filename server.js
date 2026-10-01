const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const Razorpay = require('razorpay');
const dotenv = require('dotenv');
const path = require('path');

// Load environment variables from .env
dotenv.config({ path: path.join(__dirname, '.env') });

const app = express();
const port = process.env.PORT || 5000;

app.use(cors());
app.use(express.json());

// Root Health Check Route
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    service: 'IZYHEAT Razorpay Payment Server',
    keyConfigured: Boolean(process.env.RAZORPAY_KEY_ID && process.env.RAZORPAY_KEY_SECRET),
    endpoints: {
      createOrder: 'POST /api/create-order',
      verifyPayment: 'POST /api/verify-payment',
    },
  });
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

const keyId = process.env.RAZORPAY_KEY_ID;
const keySecret = process.env.RAZORPAY_KEY_SECRET;

if (!keyId || !keySecret) {
  console.warn('WARNING: RAZORPAY_KEY_ID or RAZORPAY_KEY_SECRET is not set in environment.');
}

// Razorpay SDK Instance
const razorpay = new Razorpay({
  key_id: keyId || '',
  key_secret: keySecret || '',
});

/**
 * STEP 1: BACKEND - Create Order
 * Endpoint: POST /api/create-order
 * Request body: { amount (paise or converted), currency, receipt }
 * Return: { order_id, amount, currency }
 * Minimum amount: 100 paise
 */
app.post('/api/create-order', async (req, res) => {
  try {
    if (!keyId || !keySecret) {
      return res.status(401).json({ error: 'Razorpay credentials not configured on server' });
    }

    let { amount, currency = 'INR', receipt, notes } = req.body;

    if (!amount || isNaN(amount)) {
      return res.status(400).json({ error: 'Valid amount is required' });
    }

    amount = parseInt(amount, 10);

    // Validate minimum amount: 100 paise (₹1.00)
    if (amount < 100) {
      return res.status(400).json({
        error: 'Invalid amount. Minimum transaction amount is 100 paise (₹1.00)',
      });
    }

    const orderOptions = {
      amount, // Amount in paise
      currency: currency.toUpperCase(),
      receipt: receipt || `receipt_${Date.now()}`,
      notes: notes || {},
    };

    const order = await razorpay.orders.create(orderOptions);

    return res.status(200).json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      receipt: order.receipt,
      status: order.status,
    });
  } catch (error) {
    console.error('Error creating Razorpay order:', error);
    return res.status(500).json({
      error: 'Failed to create Razorpay order',
      details: error.error ? error.error.description : error.message,
    });
  }
});

/**
 * STEP 3: BACKEND - Verify Signature
 * Endpoint: POST /api/verify-payment
 * Algorithm: HMAC-SHA256(order_id + "|" + payment_id, KEY_SECRET)
 * Compare generated signature with razorpay_signature
 * Return success only if signatures match
 */
app.post('/api/verify-payment', (req, res) => {
  try {
    if (!keySecret) {
      return res.status(401).json({ error: 'Razorpay secret key not configured on server' });
    }

    const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = req.body;

    if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters: razorpay_order_id, razorpay_payment_id, razorpay_signature',
      });
    }

    // Expected signature: HMAC-SHA256(order_id + "|" + payment_id, KEY_SECRET)
    const body = `${razorpay_order_id}|${razorpay_payment_id}`;
    const expectedSignature = crypto
      .createHmac('sha256', keySecret)
      .update(body.toString())
      .digest('hex');

    const isSignatureValid = expectedSignature === razorpay_signature;

    if (!isSignatureValid) {
      return res.status(400).json({
        success: false,
        error: 'Payment verification failed: Signature mismatch',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Payment verified successfully',
      payment_id: razorpay_payment_id,
      order_id: razorpay_order_id,
    });
  } catch (error) {
    console.error('Error verifying payment signature:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error while verifying payment',
    });
  }
});

app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    gateway: 'Razorpay',
    key_configured: Boolean(keyId && keySecret),
  });
});

app.listen(port, () => {
  console.log(`Razorpay Payment Server running at http://localhost:${port}`);
});
