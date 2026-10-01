const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

const ALERTS_TOPIC = 'alerts';

exports.notifyReport = onDocumentCreated(
  {
    document: 'signalements/{postId}',
  },
  async (event) => {
    const report = event.data?.data();

    if (!report) {
      return;
    }

    const disease = String(
      report.disease || 'Une maladie',
    )
      .trim()
      .slice(0, 80);

    const locality = String(
      report.locality || 'votre zone',
    )
      .trim()
      .slice(0, 80);

    const authorId = String(report.authorId || '');

    await admin.messaging().send({
      topic: ALERTS_TOPIC,
      notification: {
        title: 'Nouveau signalement',
        body: `${disease} signalée près de ${locality}`,
      },
      data: {
        type: 'community_report',
        postId: event.params.postId,
        disease,
        locality,
        authorId,
      },
    });
  },
);