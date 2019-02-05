/////////////// CyObjects.proto ///////////////

#if !defined(__GNUC__)
#define GCC_VERSION (__GNUC__ * 10000 \
                     + __GNUC_MINOR__ * 100 \
                     + __GNUC_PATCHLEVEL__)
/* Test for GCC > 4.9.0 */
#if GCC_VERSION < 40900
#error atomic.h works only with GCC newer than version 4.9
#endif /* GNUC >= 4.9 */

#endif /* Has GCC */

#ifdef __cplusplus
  #if __cplusplus >= 201103L
    #include <atomic>
    using namespace std;
    #define CyObject_ATOMIC_REFCOUNT_TYPE atomic_int

    class CyObject {
        private:
          CyObject_ATOMIC_REFCOUNT_TYPE ob_refcnt;
        public:
          CyObject(): ob_refcnt(1) {}
          virtual ~CyObject() {}
          void CyObject_INCREF();
          int CyObject_DECREF();
    };

    static inline int _Cy_DECREF(CyObject *op) {
        return op->CyObject_DECREF();
    }

    static inline void _Cy_INCREF(CyObject *op) {
        op->CyObject_INCREF();
    }

    /* Cast argument to CyObject* type. */
    #define _CyObject_CAST(op) op

    #define Cy_INCREF(op) do {if (op != NULL) {_Cy_INCREF(_CyObject_CAST(op));}} while(0)
    #define Cy_DECREF(op) do {if (_Cy_DECREF(_CyObject_CAST(op))) {op = NULL;}} while(0)
    #define Cy_XDECREF(op) do {if (op != NULL) {Cy_DECREF(op);}} while(0)
    #define Cy_GOTREF(op)
    #define Cy_XGOTREF(op)
    #define Cy_GIVEREF(op)
    #define Cy_XGIVEREF(op)
  #endif
#endif


/////////////// CyObjects ///////////////

#ifdef __cplusplus
  #include <cstdlib>
  #include <cstddef>
// atomic is already included in ModuleSetupCode
//  #include <atomic>
#else
  #error C++ needed for cython+ nogil classes
#endif /* __cplusplus */

void CyObject::CyObject_INCREF()
{
  atomic_fetch_add(&(this->ob_refcnt), 1);
}

int CyObject::CyObject_DECREF()
{
  if (atomic_fetch_sub(&(this->ob_refcnt), 1) == 1) {
    delete this;
    return 1;
  }
  return 0;
}
