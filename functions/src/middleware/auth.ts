import {Request, Response, NextFunction} from "express";
import * as admin from "firebase-admin";

export type AuthedUser = {
  uid: string;
  orgId: string;
  role?: string;
};

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: AuthedUser;
    }
  }
}

/**
 * Express middleware enforcing Firebase Auth, optional App Check,
 * and active org membership.
 *
 * @param {Object} opts Options.
 * @return {Function} Middleware handler.
 */
export function requireAuth(opts?: {requireAppCheck?: boolean}): (
  req: Request,
  res: Response,
  next: NextFunction
) => Promise<void> {
  const requireAppCheck = opts?.requireAppCheck !== false;

  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      // Check Authorization header
      const authHeader = req.headers.authorization;
      if (!authHeader || !authHeader.startsWith("Bearer ")) {
        res.status(401).json({
          error: {
            code: "UNAUTHENTICATED",
            message: "Missing or invalid Authorization header",
          },
        });
        return;
      }

      const idToken = authHeader.split("Bearer ")[1];

      // Verify ID token
      let decodedToken: admin.auth.DecodedIdToken;
      try {
        decodedToken = await admin.auth().verifyIdToken(idToken);
      } catch (error) {
        res.status(401).json({
          error: {
            code: "UNAUTHENTICATED",
            message: "Missing or invalid Authorization header",
          },
        });
        return;
      }

      const uid = decodedToken.uid;

      // Verify App Check token if required
      if (requireAppCheck) {
        const appCheckToken = req.headers["x-firebase-appcheck"] as string;
        if (!appCheckToken) {
          res.status(401).json({
            error: {
              code: "UNAUTHENTICATED",
              message: "Missing or invalid Authorization header",
            },
          });
          return;
        }

        try {
          await admin.appCheck().verifyToken(appCheckToken);
        } catch (error) {
          res.status(401).json({
            error: {
              code: "UNAUTHENTICATED",
              message: "Missing or invalid Authorization header",
            },
          });
          return;
        }
      }

      // Check X-Org-Id header
      const orgId = req.headers["x-org-id"] as string;
      if (!orgId) {
        res.status(403).json({
          error: {
            code: "FORBIDDEN",
            message: "Missing X-Org-Id",
          },
        });
        return;
      }

      // Load membership from Firestore
      const membershipDocId = `${orgId}_${uid}`;
      const membershipDoc = await admin
        .firestore()
        .collection("org_members")
        .doc(membershipDocId)
        .get();

      if (!membershipDoc.exists) {
        res.status(403).json({
          error: {
            code: "FORBIDDEN",
            message: "Access denied",
          },
        });
        return;
      }

      const membershipData = membershipDoc.data();
      if (!membershipData) {
        res.status(403).json({
          error: {
            code: "FORBIDDEN",
            message: "Access denied",
          },
        });
        return;
      }

      // Check status and deletedAt
      if (membershipData.status !== "active") {
        res.status(403).json({
          error: {
            code: "FORBIDDEN",
            message: "Access denied",
          },
        });
        return;
      }

      if (membershipData.deletedAt !== null &&
          membershipData.deletedAt !== undefined) {
        res.status(403).json({
          error: {
            code: "FORBIDDEN",
            message: "Access denied",
          },
        });
        return;
      }

      // Attach user to request
      req.user = {
        uid,
        orgId,
        role: membershipData.role,
      };

      next();
    } catch (error) {
      res.status(500).json({
        error: {
          code: "INTERNAL",
          message: "Internal server error",
        },
      });
    }
  };
}


