import tkinter as tk
from tkinter import ttk, messagebox
import firebase_admin
from firebase_admin import credentials, firestore

# --- 최종 설정 ---
# 1. Firebase 서비스 계정 키(JSON 파일)의 전체 경로
SERVICE_ACCOUNT_KEY_PATH = "D:\\flutterapp\\joybank_py\\service_key.json"

# 2. Firebase 프로젝트의 데이터베이스 URL
DATABASE_URL = "https://joybank-9636f.firebaseio.com"
# --- 설정 끝 ---

class FirebaseViewerApp:
    def __init__(self, root):
        self.root = root
        self.root.title("JoyBank 계정 뷰어")
        self.root.geometry("400x200")

        self.db = None
        self.users_data = {}

        main_frame = ttk.Frame(self.root, padding="20")
        main_frame.pack(fill=tk.BOTH, expand=True)

        ttk.Label(main_frame, text="사용자를 선택하세요:", font=("Helvetica", 12)).pack(pady=(0, 5))

        self.user_combobox = ttk.Combobox(main_frame, state="readonly", font=("Helvetica", 11))
        self.user_combobox.pack(fill=tk.X, pady=5)
        self.user_combobox.bind("<<ComboboxSelected>>", self.on_user_select)

        self.balance_label = ttk.Label(main_frame, text="잔액: ", font=("Helvetica", 14, "bold"))
        self.balance_label.pack(pady=20)

        self.initialize_firebase()
        if self.db:
            self.load_users()

    def initialize_firebase(self):
        try:
            cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
            if not firebase_admin._apps:
                firebase_admin.initialize_app(cred, {'databaseURL': DATABASE_URL})
            self.db = firestore.client()
        except Exception as e:
            messagebox.showerror("Firebase 초기화 오류", f"Firebase 초기화에 실패했습니다.\nSERVICE_ACCOUNT_KEY_PATH를 확인하세요.\n\n오류: {e}")
            self.root.quit()

    def load_users(self):
        try:
            # 최상위 'users' 컬렉션에서 사용자 목록을 가져옴
            docs = self.db.collection("users").stream()
            user_names = []
            for doc in docs:
                doc_id = doc.id
                data = doc.to_dict()
                self.users_data[doc_id] = data
                
                display_name = data.get("name", doc_id)
                user_names.append(display_name)
                self.users_data[doc_id]['_display_name'] = display_name

            self.user_combobox['values'] = sorted(user_names)
            if not user_names:
                messagebox.showinfo("정보", "사용자를 찾을 수 없습니다.")

        except Exception as e:
            messagebox.showerror("데이터 로드 오류", f"사용자 정보를 불러오는 데 실패했습니다.\n\n오류: {e}")

    def on_user_select(self, event):
        selected_display_name = self.user_combobox.get()
        
        selected_user_id = None
        for doc_id, data in self.users_data.items():
            if data.get('_display_name') == selected_display_name:
                selected_user_id = doc_id
                break

        if selected_user_id:
            try:
                # users/{id}/accounts/main 경로로 문서를 직접 조회
                account_doc_ref = self.db.collection("users").document(selected_user_id).collection("accounts").document("main")
                account_doc = account_doc_ref.get()

                if account_doc.exists:
                    account_data = account_doc.to_dict()
                    balance = account_data.get("balance", "N/A")
                    
                    try:
                        # 숫자일 경우 콤마 포맷팅
                        formatted_balance = f"{int(balance):,}"
                    except (ValueError, TypeError):
                        formatted_balance = balance
                    
                    self.balance_label.config(text=f"잔액: {formatted_balance} 원")
                else:
                    self.balance_label.config(text="잔액: 계좌 정보 없음")

            except Exception as e:
                messagebox.showerror("계좌 정보 조회 오류", f"계좌 정보를 가져오는 중 오류가 발생했습니다.\n\n오류: {e}")
                self.balance_label.config(text="잔액: 조회 오류")
        else:
            self.balance_label.config(text="잔액: 사용자 정보를 찾을 수 없음")

if __name__ == "__main__":
    root = tk.Tk()
    app = FirebaseViewerApp(root)
    root.mainloop()
